require 'bfire/template'

module Bfire
  class Group
    include Enumerable
    include PubSub::Publisher

    attr_reader :engine
    attr_reader :hooks
    attr_reader :scale
    attr_reader :name
    attr_reader :dependencies
    attr_reader :templates
    attr_accessor :state

    def initialize(engine, name, options = {})
      @engine = engine
      @name = name
      @computes = []
      @options = {}
      @hooks = {}
      @scale = nil
      @state = :created
      @listeners = {}
      @dependencies = []

      @templates = {:default => Template.new(self)}
      @current_template = template(:default)
    end

    def run!
      on(:error) {|group| group.engine.cleanup! }
      on(:ready) {|group| group.provision! }
      merge_templates!
      engine.logger.debug "#{banner}Merged templates=#{templates.inspect}"
      check!
      templates.each do |template_name, template|
        engine.logger.debug template.inspect
        engine.logger.info "#{banner}Launching deployment at #{template_name.inspect}..."
        # TODO: populate context with dependencies
        # launch compute resources according to scale
        @computes << engine.launch_compute(template, count=1)
      end
      trigger :launched
    rescue Exception => e
      engine.logger.error "#{banner}#{e.class.name}: #{e.message}"
      engine.logger.debug e.backtrace.join("; ")
      @state = :error
      trigger :error
    end
    
    def provision!
      return true if provider.nil?
      engine.logger.info "#{banner}Provisioning..."
      if all?{|vm|
        ip = vm['nic'][0]['ip']
        engine.ssh(ip, 'root') {|s|
          unless provider.install(s)
            engine.logger.error "Failed to install provider on #{vm.inspect} (IP=#{ip})."
            false
          else
            provider.run(s) do |stream|      
              engine.logger.info "#{banner}[#{ip}] #{stream}"
            end
          end
        }
      }
        trigger :provisioned
        true
      else
        trigger :error
        false
      end
    end

    # Delegates every unknown method to the current Template, except #conf.
    def method_missing(method, *args, &block)
      if method == :conf
        engine.send(method, *args, &block)
      else
        @current_template.send(method, *args, &block)
      end
    end

    # ======================
    # = Group-only methods =
    # ======================

    def scale(range, options = {})
      @scale = options.merge(
        :range => range
      )
    end

    def at(location, &block)
      t = template(location)
      @current_template = t
      instance_eval(&block) unless block.nil?
      @current_template = template(:default)
    end

    def depends_on(group_name, &block)
      @dependencies.push [group_name, block]
    end
    
    # Define the provider to use to provision the compute resources
    # (Puppet, Chef...).
    # If <tt>selected_provider</tt> is nil, returns the current provider.
    def provider(selected_provider = nil, options = {})
      return @provider if selected_provider.nil?
      options[:modules] = engine.path_to(options[:modules]) if options[:modules]
      @provider = Provider::Puppet.new(options)
    end


    # ===========
    # = Helpers =
    # ===========

    def banner
      "[#{name}] "
    end

    # Iterates over the collection of compute resources.
    # Required for the Enumerable module.
    def each(*args, &block)
      @computes.each(*args, &block)
    end

    # Return the first <tt>how_many</tt> compute resources of the group.
    def take(how_many = :all)
      case how_many
      when :all
        @computes
      when :first
        @computes[0]
      else
        raise ArgumentError, "You must pass :all, :first, or a Fixnum" unless how_many.kind_of?(Fixnum)
        @computes.take(how_many)
      end
    end

    def active?
      state != :error
    end

    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} #{banner}(#{state})>"
    end

    def reload
      each(&:reload)
    end

    def monitor
      return unless active?
      engine.logger.info "#{banner}Monitoring group..."
      reload
      if failed = find{|compute| compute['state'] == 'FAILED'}
        engine.logger.warn "#{banner}Compute #{failed.signature} is in a FAILED state. Aborting."
        trigger :error
      elsif all?{|compute| compute['state'] == 'ACTIVE'}
        engine.logger.info "#{banner}All compute resources are ACTIVE"
        if ssh_accessible?
          engine.logger.info "#{banner}All compute resources are READY"
          trigger :ready
        else
          sleep 20
          monitor
        end
      else
        engine.logger.info "#{banner}Some compute resources are still PENDING"
        sleep 10
        monitor
      end
    end

    def ssh_accessible?
      all?{|compute|
        begin
          ip = compute['nic'][0]['ip']
          Timeout.timeout(30) do
            engine.ssh(ip, 'root', :log => false) {|s|
              s.exec!("hostname")
            }
          end
          true
        rescue Exception => e
          engine.logger.debug "#{banner}Can't SSH yet to #{compute.signature} at IP=#{ip.inspect}. Reason: #{e.class.name}, #{e.message}. Will retry later."
          false
        end
      }
    end

    protected
    def template(location = :default)
      @templates[location.to_sym] ||= Template.new(
        self,
        engine.fetch_location(location)
      )
    end
    
    def check!
      check_templates!
      if provider && !provider.valid?
        raise Error, "#{banner}#{provider.errors.map(&:inspect).join(", ")}"
      end
    end

    def check_templates!
      errors = []
      templates.each do |name, t|
        t.valid? || errors.push({name => t.errors})
      end
      raise Error, "#{banner}#{errors.map(&:inspect).join(", ")}" unless errors.empty?
    end # def check_templates!

    def merge_templates!
      default = @templates.delete(:default)
      if engine.conf[:authorized_keys]
        default.context :authorized_keys => File.read(
          File.expand_path(engine.conf[:authorized_keys])
        )
      end
      if @templates.empty?
        t = template(:any)
        @templates[t.name] = t
      end
      templates.each{|name, t|
        t.merge_defaults!(default).resolve!
      }
    end # def merge_templates!
  end
end