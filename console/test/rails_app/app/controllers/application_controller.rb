class ApplicationController < ActionController::Base
  include Console::Rescue
  helper Console::Engine.helpers

  protect_from_forgery

  def active_tab
    nil
  end

  def _routes
    console
  end
end
