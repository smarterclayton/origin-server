module Console
class ConsoleController < Console.config.parent_controller.constantize
  include Console.config.security_controller.constantize
  if Console.config.embedded_in_broker?
    include Console::Rescue
    helper Console::Engine.helpers
    [:Application, :Alias, :Authorization, :Cartridge, :Domain, :Gear, :GearGroup, :Key].each{ |sym| Console.const_missing(sym) }
  end 
  include CapabilityAware
  include DomainAware
  include SshkeyAware
  include CommunityAware
  include LogHelper

  layout 'console'

  before_filter :authenticate_user!

  protected
    def active_tab
      nil
    end
    helper_method :active_tab

    def to_boolean(param)
      ['1','on','true'].include?(param.to_s.downcase) if param
    end
end
end
