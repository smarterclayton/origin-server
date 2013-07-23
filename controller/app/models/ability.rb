module Ability

  #
  # Raise an exception unless the given actor has the specific permission on the resource.
  #
  def self.authorize!(actor, scopes, permission, resource, *resources)
    type = class_for_resource(resource) or raise OpenShift::OperationForbidden, "No actions are allowed"

    unless actor
      raise OpenShift::OperationForbidden, "You are not permitted to perform this action while not authenticated (#{permission} on #{type.to_s.underscore.humanize.downcase})"
    end

    if scopes.present? && !scopes.authorize_action?(permission, resource, actor, resources)
      raise OpenShift::OperationForbidden, "You are not permitted to perform this action with the scopes #{scopes} (#{permission} on #{type.to_s.underscore.humanize.downcase})"
    end

    if has_permission?(permission, type, actor, resource) != true
      raise OpenShift::OperationForbidden, "You are not permitted to perform this action (#{permission} on #{type.to_s.underscore.humanize.downcase})"
    end

    true
  end

  #
  # Are any of the provided permissions available for the given actor on the specific resource or resources?
  #
  def self.authorized?(actor, scopes, permissions, resource, *resources)
    type = class_for_resource(resource) or return false
    return false unless actor
    permissions = Array(permissions)
    return permissions.any?{ |p| !scopes.authorize_action?(p, resource, actor, resources) } if scopes.present? 
    permissions.any?{ |p| has_permission?(p, type, actor, resource) == true }
  end

  private
    def self.class_for_resource(resource)
      return resource if resource.is_a? Class
      resource.class
    end

    def self.has_permission?(permission, type, actor, resource)
      if Application <= type
        case permission
        when :destroy
          Role.in?(:edit, resource.role_for(actor))

        when :change_state, 
             :change_cartridge_state,
             :scale_cartridge,
             :view_code_details,
             :change_gear_quota
          Role.in?(:control, resource.role_for(actor))

        when :create_cartridge, 
             :destroy_cartridge,
             :create_alias,
             :update_alias,
             :destroy_alias 
          Role.in?(:edit, resource.role_for(actor))

        end

      elsif Domain <= type
        case permission
        when :create_application
          Role.in?(:edit, resource.role_for(actor))

        when :change_namespace
          Role.in?(:manage, resource.role_for(actor))

        when :change_gear_sizes, :destroy
          resource.owner_id == actor._id

        end

      elsif CloudUser <= type
        case permission
        when :create_key, :update_key, :destroy_key, :create_domain then resource == actor
        when :create_authorization, :update_authorization, :destroy_authorization then resource == actor
        when :destroy then resource.parent_user_id.present? && resource == actor
        end
      end
  end
end