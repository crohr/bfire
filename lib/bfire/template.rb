module Bfire
  class Template
    # Return the list of nics defined.
    attr_reader :nics
    # Return the list of disks defined.
    attr_reader :disks
    # Return the template name (i.e. the location name).
    attr_reader :name
    # Return the properties defined for this template (instance_type, etc.).
    attr_reader :properties
    # Return the list of metrics defined.
    attr_reader :metrics
    attr_reader :context
    attr_reader :instances

    # Return an Array of error messages in case this template is not valid.
    attr_reader :errors
    # Return the group this template belongs to.
    attr_reader :group

    def initialize(group, location_name = nil)
      @group = group
      @location_name = location_name
      @name = location_name
      @nics = []
      @disks = []
      @errors = []
      @metrics = []
      @properties = {}
      @context = {}
      @instances = []
    end

    def location
      @location ||= if @location_name == :default
        # noop
      else
        group.engine.fetch_location(@location_name)
      end
    end

    def context(opts = {})
      if opts.empty?
        @context
      else
        @context.merge!(opts)
      end
    end

    # Define the instance type to use.
    def instance_type(instance_type)
      @properties[:instance_type] = instance_type.to_s
    end

    # Define the image to deploy on the compute resources.
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

    # Merge this template with another one.
    # nics, disks, and metrics will be added, while other properties will be
    # merged.
    def merge_defaults!(template)
      @properties = template.properties.merge(@properties)
      @context = template.context.merge(@context)
      template.nics.each do |nic|
        @nics.unshift nic.clone
      end
      template.disks.each do |disk|
        @disks.unshift disk.clone
      end
      template.metrics.each do |metric|
        @metrics.unshift metric.clone
      end
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

    # Resolve the networks and storages required for the template to be valid.
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

    # Register a metric on the compute resources.
    def register(metric_name, options = {})
      @metrics.push options.merge(:name => metric_name)
    end

    # Exports the template to a ruby Hash, which conforms to what is expected
    # by Restfully to submit a resource.
    def to_h
      h = {}
      h.merge!(@properties)
      h['name'] = "#{group.name}--#{name}--#{SecureRandom.hex(4)}"
      h['name'] << "-#{group.tag}" if group.tag
      h['nic'] = nics
      h['disk'] = disks
      h['location'] = location
      h['context'] = @context
      h['context']['metrics'] = XML::Node.new_cdata(metrics.map{|m|
        "<metric>"+[m[:name], m[:command]].join(",")+"</metric>"
      }.join("")) unless metrics.empty?
      group.dependencies.each{|gname,block|
        h['context'].merge!(block.call(group.engine.group(gname)))
      }
      h
    end
  end # class Template
end # module Bup