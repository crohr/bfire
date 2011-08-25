module Bfire
  class Template
    attr_reader :group
    attr_reader :location
    attr_reader :config

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

    # Returns true if the template is valid.
    def valid?
      @location.validate(self)
    end
  end
end