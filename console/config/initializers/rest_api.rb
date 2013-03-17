#require 'console/rest_api/log_subscriber'
#require 'console/rest_api/railties/controller_runtime'

Console::RestApi::LogSubscriber.attach_to :active_resource

unless Rails.env.production?
  begin
    info = Console::RestApi.info
    Rails.logger.info "Connected to #{info.url} with version #{info.version}"
  rescue Exception => e
    puts e if Rails.env.development?
    Rails.logger.warn e.message
  end
end

ActiveSupport.on_load(:action_controller) do
  include Console::RestApi::Railties::ControllerRuntime
end

ActiveSupport.on_load(:action_controller) do
  Console::RestApi::Base.instantiate_observers
end

