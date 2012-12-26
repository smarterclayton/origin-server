module AuthenticationHelper
  def current_user
    @current_user
  end

  def authenticate
    login = nil
    password = nil
    @request_id = request.uuid

    if request.headers['User-Agent'] == "OpenShift"
      if params['broker_auth_key'] && params['broker_auth_iv']
        login = params['broker_auth_key']
        password = params['broker_auth_iv']
      else  
        if request.headers['broker_auth_key'] && request.headers['broker_auth_iv']
          login = request.headers['broker_auth_key']
          password = request.headers['broker_auth_iv']
        end
      end
    end
    if login.nil? or password.nil?
      authenticate_with_http_basic { |u, p|
        login = u
        password = p
      }
    end
    begin
      auth = OpenShift::AuthService.instance.authenticate(request, login, password)
      @login = auth[:username]
      @auth_method = auth[:auth_method]
      @auth_provider = auth[:provider]

      if not request.headers["X-Impersonate-User"].nil?
        subuser_name = request.headers["X-Impersonate-User"]

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
        begin
          @cloud_user = CloudUser.with_identity(@auth_provider, @login).find_by
          @identity = @cloud_user.active_identity!(@auth_provider, @login)
        rescue Mongoid::Errors::DocumentNotFound
          Rails.logger.debug "Adding user #{@login}...inside base_controller"
          @cloud_user = CloudUser.new(login: @login)
          @identity = @cloud_user.identities.build(provider: @auth_provider, uid: @login)
          @cloud_user.with(safe: true).save
          Lock.create_lock(@cloud_user)
        end
        response.header['X-OpenShift-Identity'] = @identity._id
      end

      @cloud_user.auth_method = @auth_method unless @cloud_user.nil?
    rescue OpenShift::UserException => e
      render_format_exception(e)
    rescue OpenShift::AccessDeniedException
      log_action(@request_id, 'nil', login, "AUTHENTICATE", true, "Access denied", get_extra_log_args)
      request_http_basic_authentication
    end
  end
  alias_method :authenticate_user!, :authenticate

  def get_cloud_user_info(cloud_user)
    if cloud_user
      return { :uuid  => cloud_user._id.to_s, :login => cloud_user.login }
    else
      return { :uuid  => 0, :login => 'anonymous' }
    end
  end
end
