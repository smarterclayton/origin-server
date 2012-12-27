class AuthorizationsController < BaseController
  before_filter :authenticate

  #
  # Display only non-revoked tokens (includes expired tokens).
  #
  def index
    authorizations = Doorkeeper::AccessToken.where(
                      :resource_owner_id => @cloud_user.id,
                      :revoked_at => nil).
                     order_by([:created_at, :desc]).map{ |auth| RestAuthorization.new(auth, get_url, nolinks) }
    render_success(:ok, "authorizations", authorizations, "LIST_AUTHORIZATIONS")
  end

  def create
    server = Doorkeeper::Server.new(self)

    expires_in = params[:expires_in]
    expires_in = if expires_in.present?
      unless expires_in.to_i > 0 && expires_in.to_i <= server.config.max_access_token_expires_in
        render_error(:unprocessable_entity, "The expires_in value must be a number of seconds greater than zero and less than #{server.config.max_access_token_expires_in}.", 130, "CREATE_AUTHORIZATION") and return
      end
      expires_in.to_i
    else
      server.config.access_token_expires_in
    end

    scopes = params[:scopes]
    scopes = if scopes.present?
        unless Doorkeeper::OAuth::Helpers::ScopeChecker.valid?(scopes, server.config.scopes)
          render_error(:unprocessable_entity, "One or more of the specified scopes is invalid: #{scopes.to_s}", 130, "CREATE_AUTHORIZATION") and return
        end
        Doorkeeper::OAuth::Scopes.from_string(scopes)
      else
        server.config.default_scopes
      end

    token = Doorkeeper::AccessToken.create!({
      :application_id    => (server.client_via_uid || OAuthClient.default_client).id,
      :resource_owner_id => @cloud_user.id,
      :scopes            => scopes.to_s,
      :expires_in        => expires_in,
      :note              => params[:note],
      :use_refresh_token => false
    })
    render_success(:created, "authorization", RestAuthorization.new(token, get_url, nolinks), "CREATE_AUTHORIZATION")
  end

  def update
    token = Doorkeeper::AccessToken.find_by(:token => params[:id])
    token.update_attributes!(params.slice(:note))
    render_success(:ok, "authorization", RestAuthorization.new(token, get_url, nolinks), "UPDATE_AUTHORIZATION")
  end

  def destroy
    token = Doorkeeper::AccessToken.find_by(:token => params[:id])
    token.revoked_at = 1.seconds.ago
    token.save(safe: true)
    render_success(:no_content, nil, nil, "DELETE_AUTHORIZATION", "Authorization #{params[:id]} is revoked.", true)
  rescue Mongoid::Errors::DocumentNotFound
    render_error(:not_found, "Authorization #{params[:id]} not found", 129, "DELETE_AUTHORIZATION")
  end

  def destroy_all
    Doorkeeper::AccessToken.where(:resource_owner_id => @cloud_user.id).delete_all
    render_success(:no_content, nil, nil, "DELETE_AUTHORIZATIONS", "All authorizations for  #{@cloud_user.id} are revoked.", true)
  end
end
