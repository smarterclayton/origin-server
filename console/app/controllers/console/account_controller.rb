module Console
class AccountController < ConsoleController
  def show
    @user = current_user
  end
end
end
