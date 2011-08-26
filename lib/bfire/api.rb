require 'bfire/api/base'
require 'set'

module Bfire
  module API
    class << self
      def registry
        @registry ||= Set.new
      end
      
      def register(api)
        registry.add(api)
      end
    end
  end
end
