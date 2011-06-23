require 'bfire/template'
require 'bfire/rule'

module Bfire
  class Group
    include Enumerable
    include PubSub::Publisher

    attr_reader :engine
    attr_reader :name
    attr_reader :dependencies
    attr_reader :templates
    # A free-form text tag to add to every compute name of this group.
    attr_reader :tag

    def initialize(engine, name, options = {})
      @engine = engine
      @name = name
      @tag = options.delete(:tag)
      raise Error, "Tag name can't contain two or more consecutive dashes" if @tag && @tag =~ /-{2,}/
      @options = options
      @listeners = {}
      @dependencies = []

      @templates = []
      @default_template = Template.new(self, :default)
      @current_template = @default_template

      raise Error, "Group name can only contain [a-zA-Z0-9] characters" if name !~ /[a-z0-9]+/i

      on(:error) {|group| Thread.current.group.list.each{|t|
          t[:ko] = true
          t.kill
        }
      }
      on(:ready) {|group|
        group.engine.logger.info "#{group.banner}All VMs are now ready: #{computes.map{|vm|
          [vm['name'], (vm['nic'] || []).map{|n| n['ip']}.inspect].join("=")
        }.join("; ")}"
      }
    end

    def launch_initial_resources

      merge_templates!
      engine.logger.debug "#{banner}Merged templates=#{templates.inspect}"
      check!
      if rule.launch_initial_resources
        trigger :launched
        true
      else
        trigger :error
        false
      end
    rescue Exception => e
      engine.logger.error "#{banner}#{e.class.name}: #{e.message}"
      engine.logger.debug e.backtrace.join("; ")
      trigger :error
    end

    def monitor
      rule.manage(computes)
      rule.monitor
    rescue Exception => e
      engine.logger.error "#{banner}#{e.class.name}: #{e.message}"
      engine.logger.debug e.backtrace.join("; ")
      trigger :error
    end

    def provision!(vms)
      return true if provider.nil?
      engine.logger.info "#{banner}Provisioning..."
      vms.all?{|vm|
        provisioned = false
        ip = vm['nic'][0]['ip']
        engine.ssh(ip, 'root') {|s|
          provisioned = unless provider.install(s)
            engine.logger.error "Failed to install provider on #{vm.inspect} (IP=#{ip})."
            false
          else
            result = provider.run(s) do |stream|
              engine.logger.info "#{banner}[#{ip}] #{stream}"
            end
          end
        }
        provisioned
      }
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

    def rule
      @rule ||= Rule.new(self, :initial => 1, :range => 1..1)
    end

    # Defines the scaling rule for this group
    def scale(range, options = {})
      @rule = Rule.new(self, options.merge(:range => range))
    end

    def at(location, &block)
      t = template(location)
      @current_template = t
      instance_eval(&block) unless block.nil?
      @current_template = @default_template
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
      computes.each(*args, &block)
    end

    def computes
      templates.map{|t| t.instances}.flatten
    end

    # Return the first <tt>how_many</tt> compute resources of the group.
    def take(how_many = :all)
      case how_many
      when :all
        computes
      when :first
        computes[0]
      else
        raise ArgumentError, "You must pass :all, :first, or a Fixnum" unless how_many.kind_of?(Fixnum)
        computes.take(how_many)
      end
    end

    def inspect
      "#<#{self.class.name}:0x#{object_id.to_s(16)} #{banner}>"
    end

    def reload
      each(&:reload)
    end

    def ssh_accessible?(vms)
      vms.all?{|compute|
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

    def template(location)
      t = @templates.find{|t| t.name == location}
      if t.nil?
        t = Template.new(
          self,
          location
        )
        @templates.push(t)
      end
      t
    end

    def check!
      check_templates!
      if provider && !provider.valid?
        raise Error, "#{banner}#{provider.errors.map(&:inspect).join(", ")}"
      end
    end

    def merge_templates!
      default = @default_template
      if engine.conf[:authorized_keys]
        default.context :authorized_keys => File.read(
          File.expand_path(engine.conf[:authorized_keys])
        )
      end
      if @templates.empty?
        @templates.push template(:any)
      end
      templates.each{|t|
        t.merge_defaults!(default).resolve!
      }
    end # def merge_templates!

    protected

    def check_templates!
      errors = []
      templates.each do |t|
        t.valid? || errors.push({t.name => t.errors})
      end
      raise Error, "#{banner}#{errors.map(&:inspect).join(", ")}" unless errors.empty?
    end # def check_templates!

  end
end