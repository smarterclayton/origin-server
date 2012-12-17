class SessionsController < ApplicationController
  skip_before_filter :verify_authenticity_token, :only => :create
  def create
    auth_hash[:extra][:origin] = request.env['omniauth.origin']
    render :json => auth_hash.to_json, :status => 200
  end

  protected
    def auth_hash
      request.env['omniauth.auth']
    end
end
