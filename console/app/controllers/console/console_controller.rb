module Console
class ConsoleController < Console.config.parent_controller.constantize
  include Console.config.security_controller.constantize
  include CapabilityAware
  include DomainAware
  include SshkeyAware
  include CommunityAware

  layout 'console'

  before_filter :authenticate_user!

  def active_tab
    nil
  end

  #
  # By default, all URL helpers will use the console routes
  #
  def _routes
    console
  end

  protected
    def to_boolean(param)
      ['1','on','true'].include?(param.to_s.downcase) if param
    end
end
end
