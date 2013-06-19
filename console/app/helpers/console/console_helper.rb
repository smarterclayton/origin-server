module Console::ConsoleHelper

  #FIXME: Replace with real isolation of login state
  def logout_path
    controller.respond_to?(:session_path) ? controller.session_path : nil
  end

  def new_account_password_path
    controller.respond_to?(:new_account_password_path) ? controller.new_account_password_path : nil
  end

  def root_path
    '/'
  end

  def outage_notification
  end

  def product_branding
    content_tag(:span, "<strong>Open</strong>Shift Origin".html_safe, :class => 'brand-text headline')
  end

  def product_title
    'OpenShift Origin'
  end
end
