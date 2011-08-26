module Bfire
  module Template
    class Compute
      attr_reader :group
      attr_reader :location
      attr_reader :config
      attr_reader :errors
      # The list of Bfire::Compute instances created from this template.
      attr_reader :instances

      def initialize(group, location)
        raise ArgumentError, "No group given" if group.nil?
        raise ArgumentError, "No location given" if location.nil?

        @group = group
        @location = location
        @config = {
          :disks => [],
          :nics => [],
          :metrics => [],
          :context => {}
        }
        @instances = []
      end

      # Sets the image to be deployed.
      def deploy(image_name, opts = {})
        @config[:deploy] = opts.symbolize_keys.merge(:name => image_name)
      end

      # Defines the type of the instances.
      def type(type_name)
        @config[:type] = type_name
      end

      # Attach an additional disk to the instance.
      def attach(storage_name, opts = {})
        @config[:disks].push(
          opts.symbolize_keys.merge(:name => storage_name)
        )
      end

      # Connect an additional network to the instance.
      def connect(network_name, opts = {})
        @config[:nics].push(
          opts.symbolize_keys.merge(:name => network_name)
        )
      end

      # Will register a new metric to be monitored.
      def monitor(metric_name, opts = {})
        @config[:metrics].push(
          opts.symbolize_keys.merge(:name => metric_name)
        )
      end
    
      # Stes a new context property.
      def context(key, value)
        @config[:context][key] = value
      end
      
      def merge!(template)
        nics = config.delete(:nics)
        disks = config.delete(:disks)
        metrics = config.delete(:metrics)
        ctx = template.config[:context].merge(config.delete(:context))
        @config = template.config.merge(@config)
        @config[:context] = ctx
        @config[:nics].each do |nic|
          if (original_nic = nics.find{|n| n[:name] == nic[:name]})
            nic.merge!(original_nic)
          end
        end
        @config[:disks].each do |disk|
          if (original_disk = disks.find{|d| d[:name] == disk[:name]})
            disk.merge!(original_disk)
          end
        end
        @config[:metrics].each do |metric|
          if (original_metric = metrics.find{|d| d[:name] == disk[:name]})
            metric.merge!(original_metric)
          end
        end

        self
      end
    
      # Before creating the compute resources described with this template,
      # this will make sure that the disks and nics are valid. This will set
      # the :storage attribute for each disk, and the :network attribute for
      # each nic.
      #
      # If needed, new storage and network resources will be created during
      # this process.
      def setup!
        raise Error, "#{self}: #{errors.join("; ")}" unless valid?
        @config[:disks].each{|disk|
          disk[:storage] = @location.find_or_create_storage!(
            disk[:name], @group.storage_templates
          )
        }
        @config[:nics].each{|nic|
          nic[:network] = @location.find_or_create_network!(
            nic[:name], @group.network_templates
          )
        }
        true
      end

      def deploy!
        compute = location.deploy!(self)
        instances.push compute
        compute
      end

      # Returns true if the template is valid.
      # If not, a list of errors can be retrieved by calling #errors.
      def valid?
        @errors = @location.validate(self)
        @errors.empty?
      end
      
      def to_s
        if location != :default
          "Template #{group.id}/#{location.id}"
        else
          super
        end
      end
    end
  end
end