class BaseController < ActionController::Base
  include UserActionLogger
  include OpenShift::Controller::Authentication

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

  def set_locale
    # if params[:locale] is nil then I18n.default_locale will be used
    I18n.locale = nil
  end

  # Override default Rails responder to return status code and objects from PUT/POST/DELETE requests
  def respond_with(*arguments)
    super(arguments, :responder => OpenShift::Responder)
  end

  # Generates a unique request ID to identify indivigulal REST API calls in the logs
  #
  # == Returns:
  #   GUID to identify the the request
  #DEPRECATED use request.uuid
  def gen_req_uuid
    # The request id can be generated differently to make it a bit more meaningful
    File.open("/proc/sys/kernel/random/uuid", "r") do |file|
      file.gets.strip.gsub("-","")
    end
  end

  def rest_replies_url(*args)
    return "/broker/rest/api"
  end
  
  def get_url
    #Rails.logger.debug "Request URL: #{request.url}"
    url = URI::join(request.url, "/broker/rest/")
    #Rails.logger.debug "Request URL: #{url.to_s}"
    return url.to_s
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
    
    #$requested_api_version = request.headers['X_API_VERSION'] 
    if not version_header
      $requested_api_version = API_VERSION
    else
      $requested_api_version = version_header
    end
    
    if not SUPPORTED_API_VERSIONS.include? $requested_api_version
      invalid_version = $requested_api_version
      $requested_api_version = API_VERSION
      return render_error(:not_acceptable, "Requested API version #{invalid_version} is not supported. Supported versions are #{SUPPORTED_API_VERSIONS.map{|v| v.to_s}.join(",")}")
    end
  end

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
  
  # Process all validation errors on a model and returns an array of message objects.
  #
  # == Parameters:
  #  object::
  #    MongoId model to process
  #  field_name_map::
  #    Maps an internal field name to a user visible field name. (Optional)
  def get_error_messages(object, field_name_map={})
    messages = []
    object.errors.keys.each do |key|
      field = field_name_map[key.to_s] || key.to_s
      err_msgs = object.errors.get(key)
      err_msgs.each do |err_msg|
        messages.push(Message.new(:error, err_msg, object.class.validation_map[key], field))
      end if err_msgs
    end if object && object.errors && object.errors.keys
    return messages
  end
  
  # Renders a REST response for an unsuccesful request.
  #
  # == Parameters:
  #  status::
  #    HTTP Success code. See {ActionController::StatusCodes::SYMBOL_TO_STATUS_CODE}
  #  msg::
  #    The error message returned in the REST response
  #  err_code::
  #    Error code for the message in the REST response
  #  log_tag::
  #    Tag used in action logs
  #  field::
  #    Specified the field (if any) that the message applies to.
  #  msg_type::
  #    Can be one of :error, :warning, :info. Defaults to :error
  #  messages::
  #    Array of message objects. If provided, it will log all messages in the action log and will add them to the REST response.
  #    msg,  err_code, field, and msg_type will be ignored.
  def render_error(status, msg, err_code=nil, log_tag=nil, field=nil, msg_type=nil, messages=nil, internal_error=false)
    reply = RestReply.new(status)
    if messages && !messages.empty?
      reply.messages.concat(messages)
      if log_tag
        log_msg = []
        messages.each { |msg| log_msg.push(msg.text) }
        log_action(request.uuid, @cloud_user && @cloud_user.id.to_s, @identity && @identity.id.to_s, log_tag, !internal_error, log_msg.join(', '), get_extra_log_args)
      end
    else
      msg_type = :error unless msg_type
      reply.messages.push(Message.new(msg_type, msg, err_code, field)) if msg
      log_action(request.uuid, @cloud_user && @cloud_user.id.to_s, @identity && @identity.id.to_s, log_tag, !internal_error, msg, get_extra_log_args) if log_tag
    end
    respond_with reply, :status => reply.status
  end
  
  # Renders a REST response for an exception.
  #
  # == Parameters:
  #  ex::
  #    The exception to return to the user.
  #  log_tag::
  #    Tag used in action logs
  def render_exception(ex, log_tag=nil)
    Rails.logger.error ex
    Rails.logger.error ex.backtrace
    error_code = ex.respond_to?('code') ? ex.code : 1
    if ex.kind_of? OpenShift::UserException
      status = :unprocessable_entity
    elsif ex.kind_of? OpenShift::DNSException
      status = :service_unavailable
    else
      status = :internal_server_error
    end

    internal_error = status != :unprocessable_entity
    render_error(status, ex.message, error_code, log_tag, nil, nil, nil, internal_error)
  end

  # Renders a REST response with for a succesful request.
  #
  # == Parameters:
  #  status::
  #    HTTP Success code. See {ActionController::StatusCodes::SYMBOL_TO_STATUS_CODE}
  #  type::
  #    Rest object type.
  #  data::
  #    REST Object to render
  #  log_tag::
  #    Tag used in action logs
  #  log_msg::
  #    Message to be logges in action logs
  #  publish_msg::
  #    If true, adds a message object to the REST response with type=>msg_type and message=>log_msg
  #  msg_type::
  #    Can be one of :error, :warning, :info. Defaults to :error
  #  messages::
  #    Array of message objects. If provided, it will log all messages in the action log and will add them to the REST response.
  #    publish_msg, log_msg, and msg_type will be ignored.
  def render_success(status, type, data, log_tag, log_msg=nil, publish_msg=false, msg_type=nil, messages=nil)
    reply = RestReply.new(status, type, data)
    if messages && !messages.empty?
      reply.messages.concat(messages)
      if log_tag
        log_msg = []
        messages.each { |msg| log_msg.push(msg.text) }
        log_action(request.uuid, @cloud_user && @cloud_user.id.to_s, @identity && @identity.id.to_s, log_tag, true, log_msg.join(', '), get_extra_log_args)
      end
    else
      msg_type = :info unless msg_type
      reply.messages.push(Message.new(msg_type, log_msg)) if publish_msg && log_msg
      log_action(request.uuid, @cloud_user && @cloud_user.id.to_s, @identity && @identity.id.to_s, log_tag, true, log_msg, get_extra_log_args) if log_tag
    end
    respond_with reply, :status => reply.status
  end
end
