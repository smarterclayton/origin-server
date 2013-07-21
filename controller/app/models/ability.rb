module Ability
  def self.authorize!(actor, scopes, permission, resource, *resources)
    opts = resources.extract_options!
    type = class_for_resource(resource) or raise OpenShift::OperationForbidden, "No actions are allowed"

    if actor
      if scopes.present? && !scopes.authorize_action?(permission, resource, actor, resources)
        raise OpenShift::OperationForbidden, "You are not permitted to perform this action with the scopes #{scopes} (#{permission} on #{type.to_s.underscore.humanize.downcase})"
      end

      authorized = 
        if type >= Application
          role = resource.role_for(actor)
          case permission
          when :destroy
            Role.in?(:manage, role)

          when :change_state, 
               :change_cartridge_state,
               :scale_cartridge,
               :view_code_details,
               :change_gear_quota
            Role.in?(:control, role)

          when :create_cartridge, 
               :destroy_cartridge,
               :create_alias,
               :update_alias,
               :destroy_alias 
            Role.in?(:edit, role)

          end
        elsif type >= Domain
          case permission
          when :create_application, :change_namespace, :destroy then resource.owner_id == actor._id
          end
        elsif type >= CloudUser
          case permission
          when :create_key, :update_key, :destroy_key, :create_domain then resource == actor
          when :create_authorization, :update_authorization, :destroy_authorization then resource == actor
          when :destroy then resource.parent_user_id.present?
          end
        end

      if authorized != true
        raise OpenShift::OperationForbidden, "You are not permitted to perform this action (#{permission} on #{type.to_s.underscore.humanize.downcase})"
      end
    else
      raise OpenShift::OperationForbidden, "You are not permitted to perform this action while not authenticated (#{permission} on #{type.to_s.underscore.humanize.downcase})"
    end
    true
  end  

  private
    def self.class_for_resource(resource)
      return resource if resource.is_a? Class
      resource.class.to_s.camelize.safe_constantize
    end

end