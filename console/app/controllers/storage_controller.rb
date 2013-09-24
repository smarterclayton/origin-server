class StorageController < ConsoleController
  before_filter :user_information
  before_filter :application_information

  def show
  end

  def update
    @cartridge = @application.find_cartridge(params[:id]) or raise RestApi::ResourceNotFound.new(Cartridge.model_name, params[:id])

    @cartridge.additional_gear_storage = Integer(params[:cartridge][:additional_gear_storage])

    if @cartridge.save
      redirect_to application_storage_path(@application), :flash => {:success => "Updated storage for cartridge '#{@cartridge.display_name}'"}
    else
      flash.now[:error] = @cartridge.errors.messages.values.flatten
      render :show
    end
  end

  private
  def user_information
    # TODO: look up domain capabilities here
    @user = User.find :one, :as => current_user
    @max_storage = @user.capabilities[:max_storage_per_gear] || 0
    @can_modify_storage = @max_storage > 0
  end

  def application_information
    @application = Application.find(params[:application_id], :as => current_user)
    @gear_groups = @application.cartridge_gear_groups
  end
end
