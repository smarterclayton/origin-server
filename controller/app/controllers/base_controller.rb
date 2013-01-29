class BaseController < ActionController::Base
  include OpenShift::Controller::ActionLog
  include OpenShift::Controller::ApiBehavior
  include OpenShift::Controller::ApiResponses
  include OpenShift::Controller::Authentication

  before_filter :set_locale,
                :check_nolinks,
                :check_version,
                :authenticate_user!
end
