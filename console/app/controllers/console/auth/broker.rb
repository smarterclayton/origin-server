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

        def persisted?
          false
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
          session[:login] = user.login
          true
        end

        def user_session_ended
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
            BrokerUser.new :login => login
          end
        end
    end
  end
end