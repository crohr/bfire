require 'uuidtools'

module Bfire
  class Template
    attr_reader :nics
    attr_reader :disks
    attr_reader :location
    attr_reader :name
    attr_reader :properties
    attr_reader :errors
    attr_reader :group
    
    # Expects a Restfully::Resource object representing a BonFIRE location.
    def initialize(group, location = nil)
      @group = group
      @location = location
      @name = @location['name'] unless @location.nil?
      @nics = []
      @disks = []
      @errors = []
      @properties = {}
    end

    def instance_type(instance_type)
      @properties[:instance_type] = instance_type.to_s
    end

    def provider(provider = nil, options = {})
      @properties[:provider] = options.merge(
        :provider => provider
      )
    end

    def deploy(storage, options = {})
      props = options.merge(
        :storage => storage
      )
      if @disks.empty?
        @disks.push props
      else
        @disks[0] = props
      end
    end

    def connect_to(network, options = {})
      @nics.push options.merge(
        :network => network
      )
    end
    
    def merge_defaults!(template)
      template.nics.each do |nic|
        @nics.unshift nic.clone
      end
      template.disks.each do |disk|
        @disks.unshift disk.clone
      end
      @properties = template.properties.merge(@properties)
      self
    end

    # Returns true if valid, false otherwise
    def valid?
      @errors = []
      @errors.push("You must specify an instance_type") unless properties[:instance_type]
      @errors.push("You must specify at least one disk image") if @disks.empty?
      @errors.push("You must specify at least one network attachment") if @nics.empty?
      @errors.empty?
    end
    
    def resolve!
      nics.each{|nic|
        nic[:network] = group.engine.fetch_network(
          nic[:network], 
          location
        ) || raise(Error, "Can't find network #{nic[:network].inspect} at #{location["name"].inspect}")
      }
      disks.each{|disk|
        disk[:storage] = group.engine.fetch_storage(
          disk[:storage],
          location
        ) || raise(Error, "Can't find storage #{disk[:storage].inspect} at #{location["name"].inspect}")
      }
      self
    end
    
    # Exports the template to a ruby Hash
    def to_h
      h = {}
      h.merge!(@properties)
      h['name'] = "#{name}-compute-#{UUIDTools::UUID.random_create}"
      h['nic'] = nics
      h['disk'] = disks
      h['location'] = location
      h
    end
  end # class Template
end # module Bup