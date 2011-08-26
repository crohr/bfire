module Bfire
  module Template
    class Storage
      attr_reader :id
      attr_reader :config

      ATTRIBUTES = %w{size visibility fstype}

      def initialize(id, opts = {})
        @id = id.to_sym
        @config = {
          :persistent => false,
          :visibility => :private
        }
      end

      ATTRIBUTES.each do |att|
        define_method(att.to_sym) do |value|
          @config[att.to_sym] = value
        end
      end
      
      def persistent(value=true)
        @config[:persistent] = value
      end
      
    end
  end
end