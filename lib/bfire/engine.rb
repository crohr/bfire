require 'restfully'
require 'restfully/media_type/application_vnd_bonfire_xml'
require 'thread'
require 'net/ssh/gateway'
# Ruby Graph Library
require 'rgl/adjacency'
require 'rgl/topsort'

require 'bfire/group'

module Bfire
  class Engine
    include PubSub::Publisher

    DEBUG = Logger::DEBUG
    INFO = Logger::INFO
    WARN = Logger::WARN
    ERROR = Logger::ERROR
    UNKNOWN = Logger::UNKNOWN

    # Contain the Hash of hooks defined on events:
    attr_reader :hooks
    # Engine configuration hash:
    attr_reader :properties
    # A Restfully::Session object:
    attr_reader :session
    # The Engine state (:created, :running, :cleaning, :done)
    attr_reader :state

    def initialize
      @properties = {}
      @vmgroups = {}
      @networks = {}
      @storages = {}
      @locations = {}
      @hooks = {}
      @mutex = Mutex.new
      @experiment = nil
      @threads = []
      reset
    end

    def reset
      conf[:name] ||= "Bfire experiment"
      conf[:description] ||= "Anonymous description"
      conf[:walltime] ||= 3600
      conf[:logger] ||= Logger.new(STDOUT)
      conf[:logging] ||= INFO
      conf[:user] ||= ENV['USER']
      conf[:ssh_max_attempts] ||= 3
    end

    # Returns the directed acyclic graph for the given group names, based on
    # their declared dependencies.
    def dag(nodes)
      dg = RGL::DirectedAdjacencyGraph.new
      nodes.each{|n|
        dg.add_vertex(n)
        group(n).dependencies.each{|m, block|
          dg.add_vertex(m)
          dg.add_edge(m, n)
        }
      }

      raise Error, "Your dependency graph is not acyclic!" unless dg.acyclic?
      dg
    end

    # Launch procedure. Will execute each group in a separate thread,
    # and launch a thread to monitor experiment status.
    def run!
      on(:error) { cleanup! }

      dg = dag(@vmgroups.keys)
      topsort_iterator = dg.topsort_iterator
      logger.info "#{banner}Launching groups in the following topological order: #{topsort_iterator.clone.to_a.inspect}."

      if launch_waiting_groups(topsort_iterator)
        @vmgroups.each{|name, group|
          @threads.push Thread.new {
            Thread.current.abort_on_exception = true
            group.monitor
          }
        }
        @threads.push Thread.new {
          Thread.current.abort_on_exception = true
          monitor
        }
        # @threads.push Thread.new { monitor_experiment_metrics }
        @threads.each(&:join)
      end
    rescue Exception => e
      logger.error "#{banner}#{e.class.name}: #{e.message}"
      logger.debug e.backtrace.join("; ")
      trigger :error
    end

    # This launches the group in the topological order,
    # and waits for the end of that initialization procedure.
    def launch_waiting_groups(topsort_iterator)
      return true if topsort_iterator.at_end?
      return false if cleaning?

      # ugly, but I don't know why the lib don't give access to it...
      waiting = topsort_iterator.instance_variable_get("@waiting")
      logger.info "#{banner}Launching #{waiting.inspect}"
      # Make sure you don't touch the topsort_iterator in the each block,
      # otherwise you can get side-effects.
      waiting.each do |group_name|
        g = group(group_name)
        # in case that group was error'ed by the engine...
        next unless g.active?
        g.on(:error) { cleanup! }
        Thread.new {
          Thread.current.abort_on_exception = true
          g.run!
        }.join
      end
      waiting.length.times { topsort_iterator.forward }
      launch_waiting_groups(topsort_iterator)
    end

    # Define a new group (if block given), or return the group corresponding
    # to the given <tt>name</tt>.
    def group(name, options = {}, &block)
      if block
        @vmgroups[name.to_sym] ||= Group.new(
          self,
          name.to_sym,
          options
        )
        @vmgroups[name.to_sym].instance_eval(&block)
      else
        @vmgroups[name.to_sym]
      end
    end

    # =================================================
    # = Resource declaration/finding/creation methods =
    # =================================================

    # Returns the Restfully::Session object
    def session
      @session ||= Restfully::Session.new(
        :configuration_file => conf[:restfully_config],
        :logger => logger
      )
    end

    # Define a network. A network is location dependent.
    def network(name, options = {}, &block)
      @networks[name.to_s] = block
    end

    def fetch_network(name, location)
      sname = name.to_s
      key = [location['name'], sname].join(".")
      logger.debug "#{banner}Looking for network #{name.inspect} at #{location['name'].inspect}. key=#{key.inspect}"
      synchronize {
        # Duplicate general networks if present
        @networks[key] = @networks[sname].clone if @networks[sname]

        @networks[key] = case @networks[key]
        when Restfully::Resource
          @networks[key]
        when Proc
          @networks[key].call(name, location)
        else
          location.networks.find{|n|
            if name.kind_of?(Regexp)
              n['name'] =~ name
            else
              n['name'] == sname
            end
          }
        end
      }
      @networks[key]
    end

    # Define a storage. A storage is location dependent.
    def storage(name, options = {}, &block)
      @storages[name.to_s] = block
    end

    def fetch_storage(name, location)
      sname = name.to_s
      key = [location['name'], sname].join(".")
      logger.debug "#{banner}Looking for storage #{name.inspect} at #{location['name'].inspect}. key=#{key.inspect}"
      synchronize {
        # Duplicate general storages if present
        @storages[key] = @storages[sname].clone if @storages[sname]

        @storages[key] = case @storages[key]
        when Restfully::Resource
          @storages[key]
        when Proc
          @storages[key].call(name, location)
        else
          location.storages.find{|n|
            if name.kind_of?(Regexp)
              n['name'] =~ name
            else
              n['name'] == sname
            end
          }
        end
      }
      @storages[key]
    end

    def fetch_location(name)
      name = name.to_sym
      location = if (name == :any)
         choices = session.root.locations
         return nil if choices.length == 0
         choices[rand(choices.length)]
      else
        @locations[name] || session.root.locations[name]
      end
      raise Error, "#{banner}Can't find #{name.inspect} location" if location.nil?
      synchronize {
        @locations[location['name'].to_sym] ||= location
      }
      location
    end

    # Laucnh a number of compute resources based on the given
    # <tt>template</tt>.
    def launch_compute(template, count = 1)
      h = template.to_h
      logger.debug "#{banner}Launching compute with the following data: #{h.inspect}"
      experiment.computes.submit(h)
    end

    # Find or creates the experiments container.
    # Returns a Restfully::Resource object.
    def experiment
      @experiment ||= synchronize {
        session.root.experiments.submit(
          :name => conf[:name],
          :description => conf[:description],
          :walltime => conf[:walltime]
        )
      }
    end

    # =========================
    # = Configuration methods =
    # =========================

    # Sets the given <tt>property</tt> to the given <tt>value</tt>.
    def set(property, value)
      @properties[property.to_sym] = value
    end

    # Returns the configuration Hash.
    def conf
      @properties
    end

    # =====================
    # = Cleanup procedure =
    # =====================

    def cleanup!
      # TODO: we may want a proper state machine here.
      synchronize{
        return true if cleaning?
        @state = :cleaning
      }
      @vmgroups.each{|name, g| g.trigger :error}
      logger.warn "#{banner}Cleaning up in 5 seconds. Hit CTRL-C now to keep your experiment running."
      sleep 5
      @experiment.delete unless @experiment.nil?
    end


    # ===================
    # = Helpers methods =
    # ===================

    def engine
      self
    end

    def banner
      "[BFIRE] "
    end

    # Returns true if engine is cleaning up.
    def cleaning?
      state == :cleaning
    end

    # Returns the logger for the engine.
    def logger
      @logger ||= begin
        l = conf[:logger]
        l.level = conf[:logging]
        l
      end
    end

    # Synchronization primitive
    def synchronize(&block)
      @mutex.synchronize { block.call }
    end


    # ===============
    # = SSH methods =
    # ===============

    # Setup an SSH connection as <tt>username</tt> to <tt>fqdn</tt>.
    # @param [String] fqdn the fully qualified domain name of the host to connect to.
    # @param [String] username the login to use to connect to the host.
    # @param [Hash] options a hash of additional options to pass.
    # @yield [Net::SSH::Connection::Session] ssh a SSH handler.
    #
    # By default, the SSH connection will be retried at most <tt>ssh_max_attempts</tt> times if the host is unreachable. You can overwrite that default locally by passing a different <tt>ssh_max_attempts</tt> option.
    # Same for <tt>:timeout</tt> and <tt>:keys</tt> options.
    #
    # If option <tt>:multi</tt> is given and true, then an instance of Net::SSH::Multi::Session is yielded. See <http://net-ssh.github.com/multi/v1/api/index.html> for more information.
    def ssh(fqdn, username, options = {}, &block)
      raise ArgumentError, "You MUST provide a block when calling #ssh" if block.nil?
      log = !!options[:log]
      options[:timeout] ||= 10
      if options.has_key?(:password)
        options[:auth_methods] ||= ['keyboard-interactive']
      else
        options[:keys] ||= [conf[:key]].compact
      end
      max_attempts = options[:max_attempts] || conf[:ssh_max_attempts]
      logger.info "#{banner}SSHing to #{username}@#{fqdn.inspect}..." if log
      attempts = 0
      begin
        attempts += 1
        if options[:multi]
          Net::SSH::Multi.start(
            :concurrent_connections => (
              options[:concurrent_connections] || 10
            )
          ) do |s|
            s.via conf[:gateway], conf[:user] unless conf[:gateway].nil?
            fqdn.each {|h| s.use "#{username}@#{h}"}
            block.call(s)
          end
        else
          if conf[:gateway]
            gw_handler = Net::SSH::Gateway.new(conf[:gateway], conf[:user], :forward_agent => true)
            gw_handler.ssh(fqdn, username, options, &block)
            gw_handler.shutdown!
          else
            Net::SSH.start(fqdn, username, options, &block)
          end
        end
      rescue Errno::EHOSTUNREACH => e
        if attempts <= max_attempts
          logger.info "#{banner}No route to host #{fqdn}. Retrying in 5 secs..." if log
          sleep 5
          retry
        else
          logger.info "#{banner}No route to host #{fqdn}. Won't retry." if log
          raise e
        end
      end
    end

    protected
    def monitor
      @experiment_state ||= nil
      sleep_time = nil
      logger.info "#{banner}Monitoring experiment..."
      experiment.reload
      has_changed = (@experiment_state != experiment['status'])
      case experiment['status']
      when 'waiting'
        logger.info "#{banner}Experiment is waiting. Nothing to do..."
        sleep_time = 10
      when 'running'
        logger.info "#{banner}Experiment is running."
        trigger :running if has_changed
        sleep_time = 30
      when 'terminating', 'canceling'
        trigger :stopped if has_changed
        sleep_time = 10
      when 'terminated', 'canceled'
        trigger :terminated if has_changed
      end
      @experiment_state = experiment['status']

      unless sleep_time.nil?
        sleep sleep_time
        monitor
      end
    end

  end
end