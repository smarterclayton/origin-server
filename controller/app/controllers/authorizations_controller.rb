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
    render_success(:ok, "authorizations", authorizations, "LIST_AUTHORIZATIONS")
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
      render_success(:ok, "authorization", RestAuthorization.new(token, get_url, nolinks), "CREATE_AUTHORIZATION", "Reused existing") and return if token
    end

    token = Authorization.create!({
      :expires_in        => expires_in,
      :scope             => scopes.to_s,
      :note              => params[:note],
    }) do |t|
      t.user = current_user
    end
    render_success(:created, "authorization", RestAuthorization.new(token, get_url, nolinks), "CREATE_AUTHORIZATION", "Expires at #{token.expired_time}")
  end

  def update
    token = Authorization.find(params[:id])
    token.update_attributes!(params.slice(:note))
    render_success(:ok, "authorization", RestAuthorization.new(token, get_url, nolinks), "UPDATE_AUTHORIZATION")
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
    render_success(:no_content, nil, nil, "DELETE_AUTHORIZATIONS", "All authorizations for  #{@cloud_user.id} are revoked.", true)
  end
end
