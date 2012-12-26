class AuthorizationsController < BaseController
  before_filter :authenticate

  def index
    authorizations = Doorkeeper::AccessToken.where(:resource_owner_id => @cloud_user.id,
                           :revoked_at => nil).
                     order_by([:created_at, :desc]).map{ |auth| RestAuthorization.new(auth, get_url, nolinks) }
    render_success(:ok, "applications", authorizations, "LIST_AUTHORIZATIONS")
  end

  def destroy
    #domain = Domain.find_by(owner: @cloud_user, namespace: domain_id)
    #@domain_name = domain.namespace
    #log_action(@request_id, @cloud_user._id.to_s, @cloud_user.login, "DELETE_AUTHORIZATION", true, "Found domain #{domain_id}")
    token = Doorkeeper::AccessToken.find_by(:token => params[:id])
    token.revoked_at = 1.seconds.ago
    token.save(safe: true)
    render_success(:no_content, nil, nil, "DELETE_AUTHORIZATION", "Authorization #{params[:id]} is revoked.", true) 
  rescue Mongoid::Errors::DocumentNotFound
    render_error(:not_found, "Authorization #{params[:id]} not found", 129, "DELETE_AUTHORIZATION")
  end
end
