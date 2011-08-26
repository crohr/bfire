module Bfire

  # This class evaluates the given DSL, and builds the initial deployment
  # configuration.
  class Sandbox
    extend Forwardable
    
    attr_reader :campaign

    def initialize(campaign)
      @campaign = campaign
    end

    def load(dsl)
      instance_eval(dsl)
    end

    # Define a new group that will define a number of compute templates.
    def group(id, options = {}, &block)
      id = id.to_sym
      @campaign.groups[id] ||= Group.new(
        id, @campaign, options.symbolize_keys
      )
      @campaign.groups[id].instance_eval(&block) if block
      @campaign.groups[id]
    end
    
    # Define a new network template.
    def network(id, options = {}, &block)
      id = id.to_sym
      @campaign.network_templates[id] ||= Template::Network.new(
        id, options.symbolize_keys
      )
      @campaign.network_templates[id].instance_eval(&block) if block
      @campaign.network_templates[id]
    end
    
    # Define an new storage template.
    def storage(id, options = {}, &block)
      id = id.to_sym
      @campaign.storage_templates[id] ||= Template::Storage.new(
        id, options.symbolize_keys
      )
      @campaign.storage_templates[id].instance_eval(&block) if block
      @campaign.storage_templates[id]
    end
    
    def_delegator :campaign, :set, :set
    def_delegator :campaign, :use, :use

  end
end