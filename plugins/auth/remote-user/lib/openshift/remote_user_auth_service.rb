module OpenShift
  class RemoteUserAuthService
    # The base_controller will actually pass in a password but it can't be
    # trusted.  The trusted must only be set if the web server has verified the
    # password.
    def authenticate(login, password)
      username = request.env[trusted_header]
      raise OpenShift::AccessDeniedException if username.blank?
      {:username => username}
    end

    # DEPRECATED - Legacy controller only
    def login(request, params, cookies)
      OpenShift::Auth::BrokerKey.new.authenticate_request(request) ||
        authenticate(nil, nil)
    end

    protected
      def trusted_header
        Rails.configuration.auth[:trusted_header]
      end
  end
end
