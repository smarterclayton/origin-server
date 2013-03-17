class ApplicationController < ActionController::Base
  include Console::Rescue
  helper Console::Engine.helpers

  protect_from_forgery
end
