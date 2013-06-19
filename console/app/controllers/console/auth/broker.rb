module Console
  module Auth
    module Broker
      extend ActiveSupport::Concern

      class BrokerUser < RestApi::Credentials
        extend ActiveModel::Naming
        include ActiveModel::Conversion
        include ActiveModel::Validations

        def initialize(opts={})
          opts.each_pair { |key,value| instance_variable_set("@#{key}", value) }
        end
        def email_address
          nil
        end

        def authenticate
          login.present?
        end

        def as
          @as ||= ::CloudUser.find_or_create_by_identity(nil, login)
        end

        def persisted?
          false
        end

        def api_token
          @api_token
        end

        def to_headers
          if api_token.present?
            {'Authorization' => "Bearer #{api_token}"}
          else
            {}
          end
        end        
      end

      included do
        helper_method :current_user, :user_signed_in?, :previously_signed_in?

        rescue_from ActiveResource::UnauthorizedAccess, :with => :console_access_denied
      end

      # return the current authenticated user or nil
      def current_user
        @authenticated_user ||= user_from_session
      end

      # This method should test authentication and handle if the user is unauthenticated
      def authenticate_user!
        logger.debug(session[:login])
        redirect_to new_session_path(:then => request.fullpath || default_after_login_redirect) unless user_signed_in?
      end

      def user_signed_in?
        not current_user.nil?
      end

      def previously_signed_in?
        cookies[:prev_login] ? true : false
      end

      protected
        def console_access_denied
          logger.debug "Console access denied"
          redirect_to session_path
        end

        def new_user(params)
          BrokerUser.new(params.slice(:login, :password))
        end

        def authenticated_user(user)
          return false unless user.login

          scopes = Scope.for!('session')
          auth = ::Authorization.reuse_token(user.as, scopes, scopes.default_expiration, "OpenShift Console (from #{request.remote_ip} on #{user_browser})")
          auth.save! unless auth.persisted?

          session[:api_token] = auth.token
          session[:login] = user.login
          true
        end

        def user_session_ended
          if token = session[:api_token].presence
            ::Authorization.where(:token => token).delete_all rescue log_error($!, "Unable to remove API token")
          end
          session.delete :api_token
        end

        #
        # Must implement if authenticated_user is implemented and can return true
        #
        def default_after_login_redirect
        end

        def default_after_logout_redirect
          new_session_path
        end

      private
        def user_from_session
          if login = session[:login]
            BrokerUser.new :login => login, :api_token => session[:api_token]
          end
        end

        def user_browser
          agent = (request.user_agent || "").downcase
          case agent
          when /safari/
              case agent
              when /mobile/
                'Safari Mobile'
              else
                'Safari'
              end
          when /firefox/
            'Firefox'
          when /opera/
            'Opera'
          when /MSIE/
            'Internet Explorer'
          else
            'browser'
          end
        end        
    end
  end
end