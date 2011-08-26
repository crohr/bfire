require 'open-uri'
require 'uuidtools'
require 'girl_friday'
# Ruby Graph Library
require 'rgl/adjacency'
require 'rgl/topsort'

require 'bfire/sandbox'
require 'bfire/group'
require 'bfire/location'

module Bfire
  class Campaign
    attr_reader :config
    attr_reader :groups
    attr_reader :network_templates
    attr_reader :storage_templates

    def initialize
      @config = {
        :name => "Bfire Campaign",
        :description => "Bfire Campaign Description"
      }
      @network_templates = {}
      @storage_templates = {}
      @groups = {}
    end
    
    def id
      @id ||= SecureRandom.hex(4)
    end

    # Creates the group definitions and resource templates from the given DSL.
    # The +io+ parameter can be any object that responds to #read, or a FILE
    # or HTTP URI.
    def load(io)
      io = Kernel.open(io) if io.kind_of?(String)
      sandbox.load(io.read)
    end

    # Sets up a new API to use.
    # Ex:
    #   use :bonfire, :username => "toto", :password => "xxxx"
    def use(api, opts = {})
      api = api.to_s.gsub(/[^a-z0-9_-]/,'')
      Kernel.require "bfire/api/#{api}"
      klass = Bfire::API.const_get(api.capitalize)
      Bfire::API.register klass.new(self, opts.symbolize_keys)
    end

    # Sets a new property.
    # The current properties can be accessed with #config.
    def set(key, value)
      @config[key.to_sym] = value
    end

    # Initializes the intial deployment configuration.
    # Mutually exclusive with #rescucitate.
    def deploy!
      iterator = dag.topsort_iterator
      in_order(iterator) do |groups_to_deploy|
        Bfire.logger.info "Launching #{groups_to_deploy.inspect}"
        # block until those groups have been deployed
        batch = GirlFriday::Batch.new(
          groups_to_deploy, :size => groups_to_deploy.length
        ) do |group_name|
          @groups[group_name].deploy!
        end
      end
    end
    
    def setup!
      Bfire::API.registry.each(&:setup!)
      groups.each do |group_id, group|
        group.setup!
      end
    end

    def start!
      setup!
      deploy!
    end

    # Returns the directed adjacency graph for the groups.
    # Raises Bfire::Error if a cycle is detected.
    def dag
      dg = RGL::DirectedAdjacencyGraph.new
      groups.each{|name, group|
        dg.add_vertex(name)
        group.dependencies.each{|(m, block)|
          dg.add_vertex(m)
          dg.add_edge(m, name)
        }
      }
      raise Error, "The group dependency graph is not acyclic!" unless dg.acyclic?
      dg
    end

    private
    def sandbox
      @sandbox ||= Sandbox.new(self)
    end
    
    def in_order(topsort_iterator, &block)
      return true if topsort_iterator.at_end?
      # ugly, but I don't know why the lib don't give access to it...
      waiting = topsort_iterator.instance_variable_get("@waiting")
      # Make sure you don't touch the topsort_iterator in the each block,
      # otherwise you can get side-effects.
      block.call(waiting)
      waiting.length.times { topsort_iterator.forward }
      in_order(topsort_iterator, &block)
    end


  end
end