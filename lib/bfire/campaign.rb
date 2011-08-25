require 'open-uri'

require 'bfire/sandbox'
require 'bfire/group'
require 'bfire/location'

module Bfire
  class Campaign
    def initialize
      
    end

    # Creates the group definitions and resource templates from the given DSL.
    def load(uri)
      sandbox.load(Kernel.open(uri).read)
    end
    
    # Initializes the intial deployment configuration.
    # Mutually exclusive with #rescucitate.
    def setup
      
    end
    
    # Resucitate a campaign from the API
    # Mutually exclusive with #setup.
    def rescucitate(id)
      
    end
    
    def start(id = nil)
      id ? rescucitate(id) : setup
    end
    
    private
    def sandbox
      Sandbox.new(self)
    end
    
  end
end