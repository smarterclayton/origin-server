class RegisterDnsOp < PendingAppOp

  field :gear_id, type: String
  field :group_instance_id, type: String

  def execute(skip_node_ops=false)
    begin
      gear = get_gear()
      gear.register_dns
    rescue OpenShift::DNSLoginException => e
      self.set_state(:rolledback)
      raise
    end
  end

  def rollback(skip_node_ops=false)
    gear = get_gear()
    gear.deregister_dns
  end

end
