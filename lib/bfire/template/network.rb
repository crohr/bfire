module Bfire
  module Template
    class Network
      attr_reader :id
      attr_reader :config

      ATTRIBUTES = %w{cidr visibility}

      def initialize(id, opts = {})
        @id = id.to_sym
        @config = {}
      end

      ATTRIBUTES.each do |att|
        define_method(att.to_sym) do |value|
          @config[att.to_sym] = value
        end
      end
    end
  end
end