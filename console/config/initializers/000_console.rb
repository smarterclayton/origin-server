if Console::Engine.embedded_in_broker?

  case
  when Rails.env.production?  then  Console.configure(ENV['CONSOLE_CONFIG_FILE'] || '/etc/openshift/console.conf')
  when Rails.env.devenv?      then  Console.configure('/etc/openshift/console-devenv.conf')
  when Rails.env.test?        then  Console.configure do |c|
                                      c.api = (ENV['CONSOLE_API_MODE'] || 'local').to_sym
                                      c.community_url = ENV['COMMUNITY_URL'] || 'https://www.openshift.com/'
                                    end
  else                              Console.configure(ENV['CONSOLE_CONFIG_FILE'] || '~/.openshift/console.conf')
  end

  ActiveSupport.on_load :action_controller do
    Broker::Application.routes.draw do
      mount Console::Engine => '/console'
    end
  end
end