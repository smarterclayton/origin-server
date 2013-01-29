module OpenShift::Controller::ActionLog
  extend ActiveSupport::Concern

  included do
    around_filter :set_logged_request
  end

  protected
    def log_action(*arguments)
      if arguments.first.is_a? CloudUser
        OpenShift::UserActionLog.with_user(arguments.shift)
      else
        arguments.shift(3)
      end
      OpenShift::UserActionLog.action(*arguments)
    end

  private
    def set_logged_request
      OpenShift::UserActionLog.begin_request(request)
      yield
    ensure
      OpenShift::UserActionLog.end_request
    end
end
