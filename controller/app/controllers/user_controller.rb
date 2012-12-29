class UserController < BaseController

  # GET /user
  def show
    # How did this line ever get called?
    # return render_error(:not_found, "User '#{@login}' not found", 99, "SHOW_USER") unless @cloud_user
    render_success(:ok, "user", get_rest_user(current_user), "SHOW_USER")
  end

  # DELETE /user
  # NOTE: Only applicable for subaccount users
  def destroy
    force = get_bool(params[:force])

    # How did this line ever get called?
    # return render_error(:not_found, "User '#{@login}' not found", 99, "DELETE_USER") unless @cloud_user
    return render_error(:forbidden, "User deletion not permitted. Only applicable for subaccount users.", 138, "DELETE_USER") unless current_user.parent_user_id

    if force
      current_user.domains.each do |domain|
        domain.applications.each do |app|
          app.destroy_app
        end if domain.applications.count > 0
        domain.delete
      end if current_user.domains.count > 0
    elsif current_user.domains.count > 0
      return render_error(:unprocessable_entity, "User '#{current_user_identity.id}' has valid domains. Either delete domains and retry the operation or use 'force' option.", 139, "DELETE_USER")
    end

    begin
      @cloud_user.delete
      render_success(:no_content, nil, nil, "DELETE_USER", "User #{current_user_identity.id} deleted.", true)
    rescue Exception => e
      return render_exception(e, "DELETE_USER")
    end
  end

  private

  def get_rest_user(cloud_user)
    if requested_api_version == 1.0
      RestUser10.new(cloud_user, get_url, nolinks)
    else
      RestUser.new(cloud_user, get_url, nolinks)
    end
  end
end
