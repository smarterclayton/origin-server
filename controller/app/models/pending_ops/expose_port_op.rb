class ExposePortOp < PendingAppOp

  field :comp_spec, type: Hash, default: {}
  field :gear_id, type: String
  field :group_instance_id, type: String

  def isParallelExecutable()
    return true
  end

  def addParallelExecuteJob(handle)
    gear = get_gear()
    component_instance = get_component_instance()
    job = gear.get_expose_port_job(component_instance)
    tag = { "expose-ports" => component_instance._id.to_s, "op_id" => self._id.to_s }
    RemoteJob.add_parallel_job(handle, tag, gear, job)
  end

end
