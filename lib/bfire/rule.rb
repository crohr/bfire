module Bfire
  # Defines an elasticity rule.
  class Rule
    attr_reader :config
    attr_reader :group

    def initialize(group, opts = {})
      @group = group
      @config = {
        :period => 5*60, :initial => 1, :range => 1..1
      }.merge(opts.symbolize_keys)
    end


    def init!
      created = scale_up(config[:initial])
      raise(
        Bfire::Error, 
        "Failed to create compute resources for group #{group.id}"
      ) unless created.length == config[:initial]
    end

    def scale_up(count = 1)
      created = (0...count).map do |i|
        sorted_templates = group.compute_templates.sort_by{|t|
          t.instances.length
        }
        template = sorted_templates.first
        begin
          template.deploy!
        rescue StandardError => e
          Bfire.logger.warn "Can't scale up: #{e.class.name} - #{e.message}"
          Bfire.logger.debug e.backtrace.join("; ")
          nil
        end
      end.compact
    end

    # def scale_down(count = 1)
    #   (0..count).map do |i|
    #     sorted_templates = group.templates.sort_by{|t| t.instances.length}
    #     vm_to_delete = sorted_templates.last.instances[0]
    #     if vm_to_delete.nil?
    #       Bfire.logger.warn "No resource to delete!"
    #     else
    #       Bfire.logger.info "Removing compute #{vm_to_delete.to_s}..."
    #       if vm_to_delete.delete
    #         sorted_templates.last.instances.delete vm_to_delete
    #         group.trigger :scaled_down
    #       end
    #     end
    #   end
    # end

  end
end