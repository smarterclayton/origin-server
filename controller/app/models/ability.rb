module Ability

  #
  # Raise an exception unless the given actor has the specific permission on the resource.
  #
  def self.authorize!(actor_or_id, scopes, permission, resource, *resources)
    type = class_for_resource(resource) or raise OpenShift::OperationForbidden, "No actions are allowed"

    unless actor_or_id
      raise OpenShift::OperationForbidden, "You are not permitted to perform this action while not authenticated (#{permission} on #{type.to_s.underscore.humanize.downcase})"
    end

    if scopes.present? && !scopes.authorize_action?(permission, resource, actor_or_id, resources)
      raise OpenShift::OperationForbidden, "You are not permitted to perform this action with the scopes #{scopes} (#{permission} on #{type.to_s.underscore.humanize.downcase})"
    end

    role = resource.role_for(actor_or_id) if resource.respond_to?(:role_for)
    if has_permission?(actor_or_id, permission, type, role, resource) != true
      raise OpenShift::OperationForbidden, "You are not permitted to perform this action (#{permission} on #{type.to_s.underscore.humanize.downcase})"
    end

    true
  end

  #
  # Are any of the provided permissions available for the given actor_or_id on the specific resource or resources?
  #
  def self.authorized?(actor_or_id, scopes, permissions, resource, *resources)
    type = class_for_resource(resource) or return false
    return false unless actor_or_id
    permissions = Array(permissions)
    return permissions.any?{ |p| !scopes.authorize_action?(p, resource, actor_or_id, resources) } if scopes.present? 
    role = resource.role_for(actor_or_id) if resource.respond_to?(:role_for)
    permissions.any?{ |p| has_permission?(actor_or_id, p, type, role, resource) == true }
  end

  #
  # Does the active have a specific permission on a given resource.  Bypasses scope checking, so only use
  # when scopes are not relevant.
  #
  def self.has_permission?(actor_or_id, permission, type, role, resource)
    if Application <= type
      case permission
      when :change_state, 
           :change_cartridge_state,
           :scale_cartridge,
           :view_code_details,
           :change_gear_quota
        Role.in?(:control, role)

      when :destroy,
           :create_cartridge, 
           :destroy_cartridge,
           :create_alias,
           :update_alias,
           :ssh_to_gears,
           :destroy_alias 
        Role.in?(:edit, role)

      when :change_members
        Role.in?(:manage, role)

      end

    elsif Domain <= type
      case permission
      when :create_application
        Role.in?(:edit, role)

      when :change_namespace, :change_members
        Role.in?(:manage, role)

      when :change_gear_sizes, :destroy
        resource.owned_by?(actor_or_id)

      end

    elsif CloudUser <= type
      case permission
      when :create_key, :update_key, :destroy_key, :create_domain then resource === actor_or_id
      when :create_authorization, :update_authorization, :destroy_authorization then resource === actor_or_id
      when :destroy then resource.parent_user_id.present? && resource === actor_or_id
      end
    end
  end

  private
    def self.class_for_resource(resource)
      return resource if resource.is_a? Class
      resource.class
    end
end