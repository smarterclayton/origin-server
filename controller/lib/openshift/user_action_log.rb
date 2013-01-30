module OpenShift::UserActionLog

  def self.begin_request(request)
    Thread.current['user_action_log/uuid'] = request ? request.uuid : nil
  end
  def self.end_request
    begin_request(nil)
    with_user(nil)
  end
  def self.with_user(user)
    Thread.current['user_action_log/user_id'] = user ? user.id : nil
    Thread.current['user_action_log/identity_id'] = user ? user.current_identity.id : nil
  end

  def self.action(action, success = true, description = "", args = {})
    return unless logger

    result = success ? "SUCCESS" : "FAILURE"
    description = description.nil? ? "" : description.strip
    time_obj = Time.new
    date = time_obj.strftime("%Y-%m-%d")
    time = time_obj.strftime("%H:%M:%S")

    message = "#{result} DATE=#{date} TIME=#{time} ACTION=#{action} REQ_ID=#{Thread.current['user_action_log/uuid']}"
    auth = " USER_ID=#{Thread.current['user_action_log/user_id'].to_s} LOGIN=#{Thread.current['user_action_log/identity_id'].to_s}"
    extra = args.map{|k,v| " #{k}=#{v}"}.join

    logger.info("#{message}#{auth}#{extra} #{description}")

    unless Rails.env.production?
      # Using a block prevents the message in the block from being executed 
      # if the log_level is lower than the one set for the logger
      Rails.logger.add(Logger::DEBUG){ "  #{result} ACTION=#{action}#{auth}#{extra} #{description}" }
    end
  end

  class << self
    attr_writer :logger
    private
      attr_reader :logger
  end
end
