class AuthorizationsController < BaseController

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

    expires_in =
      if params[:expires_in].present?
        expires_in = params[:expires_in].to_i
        expires_in = server.config.max_access_token_expires_in if expires_in <= 0 || expires_in > server.config.max_access_token_expires_in
        expires_in
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

    app_id = (server.client_via_uid || OAuthClient.default_client).id

    if params[:reuse]
      token = Doorkeeper::AccessToken.for_owner(app_id, current_user.id).
        matches_details(params[:note], scopes).
        order_by([:created_at, :desc]).
        limit(10).detect{ |i| i.expires_in_seconds > [10.minute.seconds, expires_in / 2].min }
      render_success(:ok, "authorization", RestAuthorization.new(token, get_url, nolinks), "CREATE_AUTHORIZATION") and return if token
    end

    token = Doorkeeper::AccessToken.create!({
      :application_id    => app_id,
      :resource_owner_id => current_user.id,
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
