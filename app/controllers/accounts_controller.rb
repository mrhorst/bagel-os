class AccountsController < ApplicationController
  def show
    @user = Current.user
  end

  def update
    @user = Current.user
    if @user.update(profile_params)
      redirect_to account_path, notice: "Account updated."
    else
      render :show, status: :unprocessable_entity
    end
  end

  def update_password
    @user = Current.user
    unless @user.authenticate(params.dig(:user, :current_password).to_s)
      @user.errors.add(:current_password, "is incorrect")
      return render :show, status: :unprocessable_entity
    end

    if @user.update(password_params)
      Current.session.user.sessions.where.not(id: Current.session.id).destroy_all
      redirect_to account_path, notice: "Password updated. Other sessions have been signed out."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :email_address)
  end

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
