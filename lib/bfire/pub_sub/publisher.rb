module Bfire
  module PubSub
    module Publisher
      # Notify all group listeners when event <tt>event</tt> occurs.
      def trigger(event)
        engine.logger.info "#{banner}Triggering #{event.inspect} event..."
        (@hooks[event] || []).each{|block| engine.instance_eval(&block) }
      end

      # Defines a procedure (hook) to launch when event <tt>event</tt> occurs.
      def on(event, &block)
        @hooks[event.to_sym] ||= []
        @hooks[event.to_sym] << block
      end
      
      def self.included(mod)
        @hooks = {}
      end
      
    end
  end
end
