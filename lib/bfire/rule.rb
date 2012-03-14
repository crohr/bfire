module Bfire
  class Rule
    attr_reader :group
    attr_reader :opts

    include PubSub::Publisher

    def initialize(group, opts = {})
      @group = group
      @opts = {:period => 5*60, :initial => 1, :range => 1..1, :count => 1}.merge(opts)
    end

    # we only support round-robin placement for now
    def monitor
      loop do
        sleep opts[:period]
        group.engine.logger.info "#{group.banner}Monitoring group elasticity rule..."
        # this is blocking because we don't want the rule to be triggered
        # too many times.
        if scale_up?
          group.engine.logger.info "#{group.banner}Scaling up!"
          manage(scale(:up, @opts[:count]))
        elsif scale_down?
          group.engine.logger.info "#{group.banner}Scaling down!"
          manage(scale(:down))
        else
          group.engine.logger.info "#{group.banner}..."
        end
      end
    end

    def launch_initial_resources
      scale(:up, opts[:initial])
    end

    def scale(up_or_down, count = 1)
      new_computes = []
      count.times do |i|
        sorted_templates = group.templates.sort_by{|t| t.instances.length}
        if up_or_down == :down
          vm_to_delete = sorted_templates.last.instances[0]
          if vm_to_delete.nil?
            group.engine.logger.warn "#{group.banner}No resource to delete!"
          else
            group.engine.logger.info "#{group.banner}Removing compute #{vm_to_delete.signature}..."
            if vm_to_delete.delete
              sorted_templates.last.instances.delete vm_to_delete
              group.trigger :scaled_down
            end
          end
        else
          template = sorted_templates.first
          computes = group.engine.launch_compute(template)
          template.instances.push(*computes)
          new_computes.push(*computes)
        end
      end
      new_computes
    end

    def manage(vms)
      return true if vms.empty?
      group.engine.logger.info "#{group.banner}Monitoring VMs... IPs: #{vms.map{|vm| [vm['name'], (vm['nic'] || []).map{|n| n['ip']}.inspect].join("=")}.join("; ")}."
      vms.each(&:reload)
      if failed = vms.find{|compute| compute['state'] == 'FAILED'}
        group.engine.logger.warn "#{group.banner}Compute #{failed.signature} is in a FAILED state."
        if group.triggered_events.include?(:ready)
          # group.trigger :error
        else
          group.trigger :scale_error
        end
      elsif vms.all?{|compute| compute['state'] == 'ACTIVE'}
        group.engine.logger.info "#{group.banner}All compute resources are ACTIVE"
        if group.ssh_accessible?(vms)
          group.engine.logger.info "#{group.banner}All compute resources are SSH-able"
          provisioned = group.provision!(vms)
          if group.triggered_events.include?(:ready)
            if provisioned
              group.trigger :scaled_up
            else
              group.trigger :scale_error
            end
          else
            if provisioned
              group.trigger :ready
            else
              # group.trigger :error
            end
          end
          monitor
        else
          sleep 20
          manage(vms)
        end
      else
        group.engine.logger.info "#{group.banner}Some compute resources are still PENDING"
        sleep 10
        manage(vms)
      end
    end

    def scale_up?
      opts[:up] && group.computes.length < opts[:range].end && opts[:up].call(group.engine)
    end

    def scale_down?
      opts[:down] && group.computes.length > opts[:range].begin && opts[:down].call(group.engine)
    end
  end
end
