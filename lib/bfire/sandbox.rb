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

    def group(name, options = {}, &block)
      group = @campaign.groups.find{|g| g.name.to_sym == name.to_sym}
      if block
        if group.nil?
          group = Group.new(@campaign, name.to_sym, options.symbolize_keys)
          @campaign.groups.push(group)
        end
        group.instance_eval(&block)
      else
        group
      end
    end
    
    def_delegator :@campaign, :set, :set

  end
end