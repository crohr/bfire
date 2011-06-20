module Bfire
  module PubSub
    module Publisher
      # Notify all group listeners when event <tt>event</tt> occurs.
      def trigger(event)
        triggered_events.push(event)
        engine.logger.info "#{banner}Triggering #{event.inspect} event..."
        (hooks[event] || []).each{|block| 
          if block.arity == 1
            block.call(self)
          else
            engine.instance_eval(&block) 
          end
        }
      end

      # Defines a procedure (hook) to launch when event <tt>event</tt> occurs.
      def on(event, &block)
        hooks[event.to_sym] ||= []
        hooks[event.to_sym] << block
      end

      def error?
        triggered_events.include?(:error)
      end
      
      def hooks
        @hooks ||= {}
      end
      
      def triggered_events
        @triggered_events ||= []
      end
      
      def self.included(mod)
      end

    end
  end
end
