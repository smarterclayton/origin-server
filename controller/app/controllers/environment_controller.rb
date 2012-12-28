class EnvironmentController < BaseController

  # GET /environment 
  def show
    environment = {}
    environment['domain_suffix'] = Rails.application.config.openshift[:domain_suffix] 
    render_success(:ok, "environment", environment, "GET_ENVIRONMENT",  "Showing broker environment")
  end
end
