class AuthorizationsController < BaseController

  #
  # Display only non-revoked tokens (includes expired tokens).
  #
  def index
    authorizations = Authorization.where(
                      :user => current_user,
                      :revoked_at => nil).
                     order_by([:created_at, :desc]).
                     map{ |auth| RestAuthorization.new(auth, get_url, nolinks) }
    render_success(:ok, "authorizations", authorizations, "LIST_AUTHORIZATIONS", 'List authorizations', false, nil, nil, 'IP' => request.remote_ip)
  end

  def create
    max_expires = 8.hours.seconds
    expires_in =
      if params[:expires_in].present?
        expires_in = params[:expires_in].to_i
        (expires_in <= 0 || expires_in > max_expires) ? nil : expires_in
      end || max_expires

    scopes = Authorization::Scopes::DEFAULT
    if params[:scope]
      scopes = Authorization::Scopes.from_string(params[:scope])
      return render_error(:unprocessable_entity, "The provided scope is invalid.",
                          194, "ADD_AUTHORIZATION", "scope") unless scopes.valid?
    end

    if params[:reuse]
      token = Authorization.for_owner(current_user).
        matches_details(params[:note], scopes).
        order_by([:created_at, :desc]).
        limit(10).detect{ |i| i.expires_in_seconds > [10.minute.seconds, expires_in / 2].min }
      render_success(:ok, "authorization", RestAuthorization.new(token, get_url, nolinks), "ADD_AUTHORIZATION", "Reused existing") and return if token
    end

    auth = Authorization.create!({
      :expires_in        => expires_in,
      :note              => params[:note],
    }) do |a|
      a.user = current_user
      a.scopes = scopes.to_s
    end
    render_success(:created, "authorization", RestAuthorization.new(auth, get_url, nolinks), "ADD_AUTHORIZATION", "Create authorization", false, nil, nil, 'TOKEN' => auth.token, 'SCOPE' => auth.scopes_string, 'EXPIRES' => auth.expired_time, 'IP' => request.remote_ip)
  end

  def update
    auth = Authorization.find(params[:id])
    auth.update_attributes!(params.slice(:note))
    render_success(:ok, "authorization", RestAuthorization.new(auth, get_url, nolinks), "UPDATE_AUTHORIZATION", "Change authorization", false, nil, nil, 'TOKEN' => auth.token, 'IP' => request.remote_ip)
  end

  def destroy
    token = Authorization.find(params[:id])
    token.revoked_at = 1.seconds.ago
    token.save(safe: true)
    render_success(:no_content, nil, nil, "DELETE_AUTHORIZATION", "Authorization #{params[:id]} is revoked.", true)
  rescue Mongoid::Errors::DocumentNotFound
    render_error(:not_found, "Authorization #{params[:id]} not found", 129, "DELETE_AUTHORIZATION")
  end

  def destroy_all
    Authorization.where(:user => current_user).delete_all
    render_success(:no_content, nil, nil, "DELETE_AUTHORIZATIONS", "All authorizations for #{@cloud_user.id} are revoked.", true)
  end
end
