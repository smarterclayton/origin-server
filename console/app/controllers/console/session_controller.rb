module Console
  class SessionController < ConsoleController
    layout 'simple'
    skip_before_filter :authenticate_user!
    before_filter :supports_sessions, :except => :destroy

    def new
      @redirect = safe_login_redirect(params[:then] || request.referrer)
      @user = new_user(params[:web_user] || params)
    end

    def create
      @redirect = safe_login_redirect(params[:then])
      @user = new_user(params[:web_user] || params)

      if @user.authenticate
        user_action :login, true, :login => @user.login
        if authenticated_user(@user) 
          redirect_to (@redirect || console_path)
        end
      else
        user_action :login, false, :login => @user.login
        render :new
      end      
    end

    def destroy
      @redirect = safe_logout_redirect(params[:then]) || default_after_logout_redirect

      user_action :logout, true, :login => (current_user and current_user.login)

      begin
        user_session_ended
      rescue Exception => e
        log_error(e, "Ending user session")
      end if respond_to? :user_session_ended

      reset_session
      logout_complete
    end

    protected
      def supports_sessions
        raise NotFound unless respond_to? :authenticated_user
      end

      def logout_complete
        @cause = params[:cause].presence
        case @cause
        when nil
          redirect_to @redirect if @redirect
        when 'expired'
          render :expired
        when 'change_account'
          render :change_account
        when 'server_unavailable'
          render :server_unavailable
        end
      end
  end
end