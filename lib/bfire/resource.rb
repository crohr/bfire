module Bfire
  class Resource
    attr_accessor :uri
    attr_accessor :id
    attr_accessor :name    
    
    # state_machine :state, :initial => :pending do
    #   event :stop do
    #     transition :waiting => :scheduling
    #   end
    #   event :launch do
    #     transition :scheduling => :running
    #   end
    #   event :reconfigure do
    #     transition :running => :reconfiguring
    #   end
    #   event :yield do
    #     transition :reconfiguring => :running
    #   end
    #   event :cancel do
    #     transition all-[:terminating, :canceled, :terminated] => :canceling
    #   end
    #   event :terminate do
    #     transition [:running, :terminating] => :terminating
    #   end
    #   event :done do
    #     transition :canceling => :canceled
    #     transition :terminating => :terminated
    #   end
    #   before_transition :on => :done, :do => :unregister_password_in_ldap!
    # end
    # 
    
    
    
    def save_as(storage_name)
      
    end
  end # class Resource
end # module Bup