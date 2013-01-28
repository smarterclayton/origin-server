module OpenShift
  module Controller
    module Authentication
      extend ActiveSupport::Concern

      included do
        include OpenShift::Controller::OAuth::ControllerMethods
      end

      protected
        #
        # Filter a request to require an authenticated user
        #
        # FIXME Handle exceptions more consistently, gracefully recover from misbehaving
        #  services
        def authenticate_user!
          return @cloud_user if @cloud_user

          #
          # Each authentication type may return nil if no auth info is present,
          # false if the user failed authentication (may optionally render a response),
          # or a Hash with the following keys:
          #
          #   :user
          #     If present, use this user as the current request.  The current_identity
          #     field on the user will be used as the current identity, and will not
          #     be persisted.
          #
          #   :username
          #   :provider
          #     A user unique identifier, and a scoping provider.  There are two
          #     special provider values:
          #       nil - The default provider scope
          #       access_token_on_behalf_of - reserved for use by access tokens.
          #
          info = authentication_types.find{ |i| not i.nil? }

          return if response_body
          request_http_basic_authentication and return unless info

          @cloud_user = info[:user] ?
            info[:user] :
            impersonate(CloudUser.find_or_create_by_identity(info[:provider], info[:username]))
          @identity = @cloud_user.current_identity

          @cloud_user.auth_method = info[:auth_method] || :login
          response.headers['X-OpenShift-Identity'] = @identity.id

          log_action(request.uuid, @cloud_user.id, @identity.id, "AUTHENTICATE", true, "Authenticated")

          @cloud_user
        end

        #
        # Attempt to locate a user by their credentials. No impersonation 
        # is allowed.
        #
        def authenticate_user_from_credentials(username, password)
          info =
            if auth_service.respond_to?(:authenticate) && auth_service.method(:authenticate).arity == 2
              auth_service.authenticate(username, password).tap do |info|
                log_action(request.uuid, nil, nil, "CREDENTIAL_AUTHENTICATE", false, "Access denied by auth service for #{username}") unless info
              end
            end || nil

          if info
            raise "Authentication service must return a username with its response" if info[:username].nil?

            user = CloudUser.find_or_create_by_identity(info[:provider], info[:username])
            log_action(request.uuid, user.id, user.current_identity.id, "CREDENTIAL_AUTHENTICATE", true, "Authenticated via credentials")
            user
          end
        rescue OpenShift::AccessDeniedException => e
          log_action(request.uuid, nil, nil, "CREDENTIAL_AUTHENTICATE", false, "Access denied by auth service for #{username}", {'ERROR' => e.message})
          nil
        end

        #
        # This should be abstracted to an OpenShift.config service implementation
        # that allows the product to easily reuse these without having to be exposed
        # as helpers.
        #
        def broker_key_auth
          @broker_key_auth ||= OpenShift::Auth::BrokerKey.new
        end
        # Same note as for broker_key_auth
        def auth_service
          @auth_service ||= OpenShift::AuthService.instance
        end

        #
        # Return the currently authenticated user or nil
        #
        def current_user
          @cloud_user
        end
        def current_user_identity
          @identity
        end

      private
        #
        # Lazily evaluate the authentication types on this class
        #
        def authentication_types
          Enumerator.new do |y|
            [
              :authenticate_broker_key,
              :authenticate_bearer_token,
              :authenticate_request_via_service,
              :authenticate_basic_via_service,
            ].each{ |sym| y.yield send(sym) }
          end
        end

        def authenticate_broker_key
          broker_key_auth.authenticate_request(request)
        rescue OpenShift::AccessDeniedException => e
          log_action(request.uuid, nil, nil, "AUTHENTICATE", false, "Access denied by broker key", {'ERROR' => e.message})
          false
        end

        def authenticate_bearer_token
          authenticate_with_bearer_token do |token|
            if auth = Authorization.authenticate(token)
              if auth.accessible?
                user = auth.user
                user.current_identity = Identity.for('authorization_token', auth.id, auth.created_at)
                {:user => user, :auth_method => :authorization_token}
              else
                request_http_bearer_token_authentication(:invalid_token, 'The access token expired')
                log_action(request.uuid, nil, nil, "AUTHENTICATE", false, "Access denied, token #{access_token.id} was expired")
                false
              end
            else
              request_http_bearer_token_authentication(:invalid_token, 'The access token is not recognized')
              log_action(request.uuid, nil, nil, "AUTHENTICATE", false, "Access denied, token #{access_token.id} does not exist")
              false
            end
          end
        end

        def authenticate_request_via_service
          return unless auth_service.respond_to? :authenticate_request

          auth_service.authenticate_request(self).tap do |info|
            if info == false || response_body
              log_action(request.uuid, nil, nil, "AUTHENTICATE", false, "Access denied, authenticate_request handled response")
              return false
            end
          end
        rescue OpenShift::AccessDeniedException => e
          log_action(request.uuid, nil, nil, "AUTHENTICATE", false, "Access denied by auth service on request", {'ERROR' => e.message})
          false
        end

        def authenticate_basic_via_service
          return unless auth_service.respond_to? :authenticate

          authenticate_with_http_basic do |u, p|
            next if u.blank?
            if auth_service.method(:authenticate).arity == 2
              auth_service.authenticate(u, p)
            else
              #DEPRECATED - Will be removed in favor of #authenticate_request
              auth_service.authenticate(request, u, p)
            end
          end.tap do |info|
            if info == false
              log_action(request.uuid, nil, nil, "AUTHENTICATE", false, "Access denied, login/password rejected")
            end
          end
        rescue OpenShift::AccessDeniedException => e
          log_action(request.uuid, nil, nil, "AUTHENTICATE", false, "Access denied by auth service for BASIC credentials", {'ERROR' => e.message})
          false
        end

        def impersonate(user)
          other = request.headers["X-Impersonate-User"]
          return user unless other.present?

          identity = user.current_identity

          unless user.get_capabilities && user.get_capabilities['subaccounts'] == true
            log_action(request.uuid, nil, identity.id, "IMPERSONATE", false, "Failed to impersonate #{other} as #{identity.id}, subaccount capability not set")
            raise OpenShift::AccessDeniedException, "Insufficient privileges to access user #{other}"
          end

          CloudUser.find_or_create_by_identity("impersonation/#{as.id}", other, parent_user_id: user.id) do |existing_user, existing_identity|
            if existing_user.parent_user_id != user.id
              log_action(request.uuid, nil, identity.id, "IMPERSONATE", false, "Failed to impersonate #{other} as #{identity.id}, account is not associated with the parent")
              raise OpenShift::AccessDeniedException, "Account is not associated with impersonate account #{other}"
            end
          end.tap do |other_user, other_identity|
            log_action(request.uuid, nil, identity.id, "IMPERSONATE", true, "User #{user.id} was able to impersonate as #{other_user.id}")
          end
        end
    end
  end
end
