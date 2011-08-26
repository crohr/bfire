require 'bfire/template'
require 'bfire/rule'

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
    attr_reader :id
    attr_reader :compute_templates
    attr_reader :dependencies

    def initialize(id, campaign, options = {})
      raise ArgumentError, "No campaign given" if campaign.nil?
      raise ArgumentError, "No id given" if id.nil? || id.to_s.empty?
      @campaign = campaign
      @id = id.to_sym
      @options = options
      @compute_templates = []
      @dependencies = []
    end

    # Returns the network templates declared within the group, plus those
    # defined at the campaign level.
    def network_templates
      @campaign.network_templates
    end

    # Returns the storage templates declared within the group, plus those
    # defined at the campaign level.
    def storage_templates
      @campaign.storage_templates
    end

    def default_template
      @default_template ||= begin
        t = Template::Compute.new(self, Bfire::Location.find(:any))
        t.context :authorized_keys, File.read(
          File.expand_path(@campaign.config[:authorized_keys])
        ) if @campaign.config[:authorized_keys]
        t
      end
    end

    def template(location)
      t = @compute_templates.find{|t| t.location == location}
      if t.nil?
        t = Template::Compute.new(self, location)
        @compute_templates.push(t)
      end
      t
    end

    # Configure template in the context of the given location.
    def at(location_id, opts = {}, &block)
      location = Bfire::Location.find(location_id, opts)
      raise Bfire::Error, "Can't find location #{location_id.inspect} (#{opts.inspect})" if location.nil?
      t = template(location)
      t.instance_eval(&block) unless block.nil?
    end

    TEMPLATE_METHODS = %w{deploy type attach connect monitor context}
    TEMPLATE_METHODS.each do |method|
      def_delegator :default_template, method.to_sym, method.to_sym
    end

    # Add a new dependency on another group name.
    # The dependency will be resolved after the dependent group has been
    # launched, and the block will be called with the dependent group as first
    # argument.
    def depends_on(group_name, &block)
      @dependencies.push [group_name, block]
    end

    # Defines the elasticity rule for this group.
    def scale(range, options = {})
      @rule = Rule.new(self, options.merge(:range => range))
    end

    def rule
      @rule ||= scale(:initial => 1, :range => 1..1)
    end

    def setup!
      default = default_template
      compute_templates.push(default) if compute_templates.empty?
      compute_templates.each do |t|
        t.merge!(default)
        Bfire.logger.info "Setting up required resources for #{t.to_s}..."
        t.setup!
      end
    end

    def deploy!
      rule.init!
    end

  end
end