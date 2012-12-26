class AccountController < BaseController

  def create
    username = params[:username]

    Rails.logger.debug "username = #{username}"

    log_action('nil', 'nil', username, "ADD_USER", false, "Cannot create account, managed by kerberos")
    @reply = RestReply.new(requested_api_version, :unprocessable_entity)
    @reply.messages.push(Message.new(:error, "Cannot create account, managed by kerberos", 1001, "username"))
    respond_with @reply, :status => @reply.status
  end
end
