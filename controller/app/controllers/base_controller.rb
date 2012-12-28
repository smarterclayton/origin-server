class BaseController < ActionController::Base
  respond_to :json, :xml

  API_VERSION = 1.3
  SUPPORTED_API_VERSIONS = [1.0, 1.1, 1.2, 1.3]
  #Mongoid.logger.level = Logger::WARN
  #Moped.logger.level = Logger::WARN

  # Initialize domain/app variables to be used for logging in user_action.log
  # The values will be set in the controllers handling the requests
  @domain_name = nil
  @application_name = nil
  @application_uuid = nil

  before_filter :set_locale, :check_nolinks, :check_version
  before_filter :authenticate_user!

  protected
    include UserActionLogger
    include OpenShift::Controller::ApiResponses
    include OpenShift::Controller::Authentication

    def set_locale
      # if params[:locale] is nil then I18n.default_locale will be used
      I18n.locale = nil
    end

    # Override default Rails responder to return status code and objects from PUT/POST/DELETE requests
    def respond_with(*arguments)
      super(arguments, :responder => OpenShift::Responder)
    end

    def rest_replies_url(*args)
      return "/broker/rest/api"
    end

    def get_url
      URI::join(request.url, "/broker/rest/").to_s
    end

    def nolinks
      get_bool(params[:nolinks])
    end

    def check_nolinks
      begin
        nolinks
      rescue Exception => e
        return render_exception(e)
      end
    end

    def check_version
      accept_header = request.headers['Accept']
      Rails.logger.debug accept_header    
      mime_types = accept_header.split(%r{,\s*})
      version_header = API_VERSION
      mime_types.each do |mime_type|
        values = mime_type.split(%r{;\s*})
        values.each do |value|
          value = value.downcase
          if value.include?("version")
            version_header = value.split("=")[1].delete(' ').to_f
          end
        end
      end

      version = version_header || API_VERSION

      if SUPPORTED_API_VERSIONS.include? version
        @requested_api_version = version
      else
        @requested_api_version = API_VERSION
        render_error(:not_acceptable, "Requested API version #{version} is not supported. Supported versions are #{SUPPORTED_API_VERSIONS.map{|v| v.to_s}.join(",")}")
      end
    end
    attr_reader :requested_api_version

    def get_bool(param_value)
      if param_value.is_a? TrueClass or param_value.is_a? FalseClass
        return param_value
      elsif param_value.is_a? String and param_value.upcase == "TRUE"
        return true
      else
        return false
      end
    end

    def get_extra_log_args
      args = {}
      args["APP"] = @application_name if @application_name
      args["DOMAIN"] = @domain_name if @domain_name
      args["APP_UUID"] = @application_uuid if @application_uuid
      return args
    end
end
