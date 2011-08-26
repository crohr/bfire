module Bfire
  class Resource
    extend Forwardable

    # The API resource object associated to this resource must support the
    # #delete, #update, and #reload methods.
    #
    # #delete takes no argument and must return true or false.
    #
    # #update takes a hash of attributes to update, and return the modified
    # resource.
    #
    # #reload takes no argument and returns the refreshed resource.
    def_delegator :resource, :delete, :delete
    def_delegator :resource, :update, :update
    def_delegator :resource, :reload, :reload
    
    attr_reader :id
    attr_reader :resource
    attr_reader :api

    def initialize(id, resource, api)
      @id = id.to_sym
      @resource = resource
      @api = api
    end
  end
end