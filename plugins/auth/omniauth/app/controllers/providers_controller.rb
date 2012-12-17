class ProvidersController < ApplicationController
  def index
    render :json => [
      {:id => 'developer', :name => 'Developers'},
      {:id => 'httpbasic', :name => 'Remote HTTP'},
      {:id => 'streamline', :name => 'Streamline'},
    ], :status => 200
  end
end
