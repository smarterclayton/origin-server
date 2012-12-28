module OpenShift
  module Controller
    module Authentication
      extend ActiveSupport::Concern

      included do
      end

      protected
        #
        # Filter a request to require an authenticated user
        #
        def authenticate_user!
          info = broker_key_auth.authenticate_request(request)

          # Allow a plugin to handle the entire response and challenge
          # for auth.
          if info.nil? and auth_service.respond_to? :authenticate_request
            info = instance_eval &auth_service.authenticate_request
            log_action(request.uuid, nil, nil, "AUTHENTICATE", false, "Access denied, authenticate_request handled response") and return if info == false || response_body
          end

          # Support user/password authentication
          if info.nil? and auth_service.respond_to? :authenticate
            info = authenticate_with_http_basic do |u, p|
              next nil if u.blank?
              if auth_service.method(:authenticate).arity == 2
                auth_service.authenticate(u, p)
              else
                #DEPRECATED - Will be removed in favor of #authenticate_request
                auth_service.authenticate(request, u, p)
              end || false
            end
            log_action(request.uuid, nil, nil, "AUTHENTICATE", false, "Access denied, login/password rejected") if info == false
          end

          request_http_basic_authentication and return unless info

          raise "Authentication service must return a username with its response" if info[:username].nil?

          @cloud_user, @identity = impersonate(*find_or_create_user_by_identity(info[:provider], info[:username]))

          @cloud_user.auth_method = info[:auth_method] || :login
          response.headers['X-OpenShift-Identity'] = @identity.id

          log_action(request.uuid, nil, @identity.id, "AUTHENTICATE", true, "Authenticated to #{@cloud_user.id}")

        rescue OpenShift::AccessDeniedException => e
          log_action(request.uuid, nil, nil, "AUTHENTICATE", false, "Access denied by auth service", {'ERROR' => e.message})
          request_http_basic_authentication #FIXME Return better client information (header? body?)
        #FIXME Handle auth exceptions more correctly
        #rescue => e
        #  render :status => 500, :text =>
        end

        def broker_key_auth
          @broker_key_auth ||= OpenShift::Auth::BrokerKey.new
        end

      private

        def auth_service
          @auth_service ||= OpenShift::AuthService.instance
        end

        def find_or_create_user_by_identity(provider, login, create_attributes={}, &block)
          user = CloudUser.with_identity(provider, login).find_by
          identity = user.active_identity!(provider, login)
          yield user, identity if block_given?
          [user, identity]
        rescue Mongoid::Errors::DocumentNotFound
          user = CloudUser.new(create_attributes)
          identity = user.identities.build(provider: provider, uid: login)
          user.with(safe: true).save
          Lock.create_lock(user)
          log_action(request.uuid, nil, login, "CREATE_USER", true, "Creating user for identity #{provider}, #{login}", get_extra_log_args)
          [user, identity]
        end

        def impersonate(user, identity)
          other = request.headers["X-Impersonate-User"]
          return [user, identity] unless other.present?
          #subuser_name = request.headers["X-Impersonate-User"]

          unless user.get_capabilities && user.get_capabilities['subaccounts'] == true
            log_action(request.uuid, nil, identity.id, "IMPERSONATE", false, "Failed to impersonate #{other} as #{identity.id}, subaccount capability not set")
            raise OpenShift::AccessDeniedException, "Insufficient privileges to access user #{other}"
          end

          find_or_create_user_by_identity("impersonation/#{as.id}", other, parent_user_id: user.id) do |existing_user, existing_identity|
            if existing_user.parent_user_id != user.id
              log_action(request.uuid, nil, identity.id, "IMPERSONATE", false, "Failed to impersonate #{other} as #{identity.id}, account is not associated with the parent")
              raise OpenShift::AccessDeniedException, "Account is not associated with impersonate account #{other}"
            end
          end.tap do |other_user, other_identity|
            log_action(request.uuid, nil, identity.id, "IMPERSONATE", true, "User #{user.id} was able to impersonate as #{other_user.id}")
          end
=begin
        if CloudUser.where(login: @login).exists?
          @parent_user = CloudUser.find_by(login: @login)
        else
          Rails.logger.debug "#{@login} tried to impersonate user but #{@login} user does not exist"
          raise OpenShift::AccessDeniedException.new "Insufficient privileges to access user #{subuser_name}"
        end

        parent_capabilities = @parent_user.get_capabilities
        if parent_capabilities.nil? || !parent_capabilities["subaccounts"] == true
          Rails.logger.debug "#{@parent_user.login} tried to impersonate user but does not have require capability."
          raise OpenShift::AccessDeniedException.new "Insufficient privileges to access user #{subuser_name}"
        end        

        if CloudUser.where(login: subuser_name).exists?
          subuser = CloudUser.find_by(login: subuser_name)
          if subuser.parent_user_id != @parent_user._id
            Rails.logger.debug "#{@parent_user.login} tried to impersinate user #{subuser_name} but does not own the subaccount."
            raise OpenShift::AccessDeniedException.new "Insufficient privileges to access user #{subuser_name}"
          end
          @cloud_user = subuser
        else
          Rails.logger.debug "Adding user #{subuser_name} as sub user of #{@parent_user.login} ...inside base_controller"
          @cloud_user = CloudUser.new(login: subuser_name, parent_user_id: @parent_user._id)
          @cloud_user.with(safe: true).save
          Lock.create_lock(@cloud_user)
        end
      else
=end
        end
    end
  end
end
