class TestCallbacksController < ApplicationController
  http_basic_authenticate_with :name => "user", :password => "pass"

  def basic_auth
    render :json => {:id => 'user'}, :status => 200
  end
end
