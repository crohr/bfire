require 'thread'
require 'bfire/storage'
require 'bfire/network'
require 'bfire/compute'

module Bfire
  module API
    # Base class for APIs. Each API should subclass this class and redefine
    # the abstract methods.
    class Base
      attr_reader :config
      attr_reader :campaign
      attr_reader :config

      def initialize(campaign, opts = {})
        @campaign = campaign
        @mutex = Mutex.new
        @config = opts.symbolize_keys
      end

      def find_location(id)
        nil
      end

      def find_campaign(id)
        nil
      end

      # Check whether a template is valid or not.
      # Returns a list of errors. If empty, the template is valid.
      def validate(template)
        []
      end

      def synchronize(&block)
        @mutex.synchronize(&block)
      end
    end
  end
end