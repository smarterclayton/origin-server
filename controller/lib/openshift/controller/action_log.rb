module OpenShift::Controller::ActionLog
  extend ActiveSupport::Concern

  included do
    around_filter :set_logged_request
  end

  protected
    def log_action(*arguments)
      OpenShift::UserActionLog.action(*arguments.drop(3))
    end

  private
    def set_logged_request
      OpenShift::UserActionLog.begin_request(request)
      yield
    ensure
      OpenShift::UserActionLog.end_request
    end
end
