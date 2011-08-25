require 'bfire/template'

module Bfire

  # The Group class represents a set of Resource objects, and describes the
  # templates from which the resources are created. Resources of a same group
  # obey to the same elasticity rules, have the same dependencies, and have
  # the same provisioner.
  #
  # Other resource properties can be set per location, using the
  # #at(location){} construct.
  class Group
    extend Forwardable

    attr_reader :campaign
    attr_reader :name
    attr_reader :templates

    def initialize(campaign, name, options = {})
      raise ArgumentError, "No campaign given" if campaign.nil?
      raise ArgumentError, "No name given" if name.nil? || name.empty?
      @campaign = campaign
      @name = name.to_sym
      @options = options
      @templates = []
    end
    
    def default_template
      @default_template ||= Template.new(self, :default)
    end

    def template(location)
      l = @campaign.fetch_location(location)
      t = @templates.find{|t| t.location == l}
      if t.nil?
        t = Template.new(self, l)
        @templates.push(t)
      end
      t
    end

    # Configure template in the context of the given location.
    def at(location, &block)
      t = template(location)
      t.instance_eval(&block) unless block.nil?
    end
    
    TEMPLATE_METHODS = %w{deploy type attach connect monitor context}
    TEMPLATE_METHODS.each do |method|
      def_delegator :default_template, method.to_sym, method.to_sym
    end

  end
end