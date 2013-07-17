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
          when :change_state, 
               :change_cartridge_state,
               :scale_cartridge,
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
        elsif type >= CloudUser
          case permission
          when :create_key, :update_key, :delete_key then resource == actor
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