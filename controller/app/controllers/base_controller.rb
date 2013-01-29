class BaseController < ActionController::Base
  API_VERSION = 1.3
  SUPPORTED_API_VERSIONS = [1.0, 1.1, 1.2, 1.3]

  protected
    include OpenShift::Controller::ActionLog
    include OpenShift::Controller::ApiResponses
    include OpenShift::Controller::Authentication

    before_filter :set_locale, :check_nolinks, :check_version
    before_filter :authenticate_user!


    def set_locale
      # if params[:locale] is nil then I18n.default_locale will be used
      I18n.locale = nil
    end

    def get_url
      @rest_url ||= "#{rest_url}/"
    end

    def nolinks
      @nolinks ||= get_bool(params[:nolinks])
    end

    def check_nolinks
      begin
        nolinks
      rescue Exception => e
        return render_exception(e)
      end
    end

    def get_bool(param_value)
      return false unless param_value
      if param_value.is_a? TrueClass or param_value.is_a? FalseClass
        return param_value
      elsif param_value.is_a? String and param_value.upcase == "TRUE"
        return true
      elsif param_value.is_a? String and param_value.upcase == "FALSE"
        return false
      end
      raise OpenShift::OOException.new("Invalid value '#{param_value}'. Valid options: [true, false]", 167)
    end

    def check_version
      accept_header = request.headers['Accept']
      #Rails.logger.debug accept_header
      version_header = API_VERSION
      accept_header.split(%r{,\s*}).each do |mime_type|
        values = mime_type.split(%r{;\s*})
        values.each do |value|
          value = value.downcase
          if value.starts_with?("version")
            version_header = value.split("=")[1].delete(' ').to_f
          elsif value == 'nolinks'
            @nolinks = true
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
end
