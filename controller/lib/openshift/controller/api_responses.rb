module OpenShift
  module Controller
    module ApiResponses
      extend ActiveSupport::Concern

      included do
        respond_to :json, :xml
        self.responder = OpenShift::Responder
      end

      protected
        # Override default Rails responder to return status code and objects from PUT/POST/DELETE requests
        #def respond_with(*arguments)
        #  options = arguments.extract_options!
        #  options[:responder] = OpenShift::Responder
        #  super(*arguments, options)
        #end

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

        # Renders a REST response for an unsuccessful request.
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
          reply = RestReply.new(requested_api_version, status)
          if messages && !messages.empty?
            reply.messages.concat(messages)
            if log_tag
              log_msg = []
              messages.each { |msg| log_msg.push(msg.text) }
              log_action(request.uuid, current_user.id, current_user_identity.id, log_tag, !internal_error, log_msg.join(', '), get_extra_log_args)
            end
          else
            msg_type = :error unless msg_type
            reply.messages.push(Message.new(msg_type, msg, err_code, field)) if msg
            log_action(request.uuid, current_user.id, current_user_identity.id, log_tag, !internal_error, msg, get_extra_log_args) if log_tag
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
          Rails.logger.error "Reference ID: #{@request_id}"
          Rails.logger.error ex.message
          Rails.logger.error ex.backtrace
          error_code = ex.respond_to?('code') ? ex.code : 1
          if ex.kind_of? OpenShift::UserException
            status = :unprocessable_entity
          elsif ex.kind_of? OpenShift::DNSException
            status = :service_unavailable
          elsif ex.kind_of? OpenShift::NodeException
            status = :internal_server_error
            if ex.resultIO
              error_code = ex.resultIO.exitcode
              if ex.resultIO.errorIO && ex.resultIO.errorIO.length > 0
                message = ex.resultIO.errorIO.string.strip
              end
              message += "\nReference ID: #{@request_id}"
            end
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
          reply = RestReply.new(requested_api_version, status, type, data)
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

        def get_extra_log_args
          args = {}
          args["APP"] = @application_name if @application_name
          args["DOMAIN"] = @domain_name if @domain_name
          args["APP_UUID"] = @application_uuid if @application_uuid
          return args
        end
    end
  end
end
