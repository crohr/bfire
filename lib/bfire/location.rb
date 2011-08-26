module Bfire
  class Location    
    attr_reader :id
    # The corresponding API resource object.
    attr_reader :resource
    # The API from which the resource was fetched.
    attr_reader :api

    def initialize(id, resource, api)
      @id = id
      @resource = resource
      @api = api
      @storages = {}
      @networks = {}
    end

    def validate(template)
      @api.validate(template)
    end
    
    def deploy!(template)
      @api.create_compute(template, self) || raise(Bfire::Error, "Can't create compute resource based on template #{template}")
    end

    def find_or_create_storage!(storage_id, templates)
      storage_id = storage_id.to_sym
      existing = @storages[storage_id] || @api.find_storage(storage_id, self)
      @storages[storage_id] = if existing.nil?
        template = templates.find{|t| t.id.to_sym == storage_id }
        if template.nil?
          raise(Error, "Can't find storage #{storage_id} at location #{id}, and no template with this name declared")
        else
          @api.create_storage(template, self) || raise(Error, "Can't create storage at location #{id} based on template #{template.inspect}")
        end
      else
        existing
      end
    end
    
    def find_or_create_network!(network_id, templates)
      network_id = network_id.to_sym
      existing = @networks[network_id] || @api.find_network(network_id, self)
      @networks[network_id] = if existing.nil?
        template = templates.find{|t| t.id.to_sym == network_id }
        if template.nil?
          raise(Error, "Can't find network #{network_id} at location #{id}, and no template with this name declared")
        else
          @api.create_network(template, self) || raise(Error, "Can't create network at location #{id} based on template #{template.inspect}")
        end
      else
        existing
      end
    end

    class << self
      def find(name, opts = {})
        location = nil
        Bfire::API.registry.each do |api|
          location = api.find_location(name)
          break unless location.nil?
        end
        location
      end
    end
  end
end