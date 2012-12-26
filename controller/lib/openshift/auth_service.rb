module OpenShift
  class AuthService
    @oo_auth_provider = OpenShift::AuthService

    def self.provider=(provider_class)
      @oo_auth_provider = provider_class
    end

    def self.instance
      @oo_auth_provider.new
    end

    #
    # The 3 argument version of this method authenticate(request,login,password) is 
    # deprecated.
    #
    # Authenticate a user/password pair. Returns:
    #
    #  nil/false if the authentication info is invalid
    #  A Hash containing the following keys if the info is valid:
    #
    #    :username - the unique identifier of this user
    #    :provider (optional) - a scope under which this username is unique
    #
    def authenticate(login, password)
      {:username => login}
    end

    #
    # The authenticate_request may be optionally implemented.  It will be executed in the 
    # current Rails controller context, allowing the consumer access to the standard
    # Rails controller method variables.  Use this method if you need access to other
    # parameters
    #
    # Implementors may write to the response to signal to a client that the request has failed.
    #
    #
    # def authenticate_request
    # end

    # DEPRECATED: Will be removed once the legacy controllers are removed
    def login(request, params, cookies)
      OpenShift::Auth::BrokerKey.new.authenticate_request(request) ||
        begin
          data = JSON.parse(params['json_data'])
          {:username => data["rhlogin"], :auth_method => :login}
        end
    end
  end
end
