module Admin
  class UsersController < ApplicationController
    before_action :require_admin!
    before_action :set_user, only: %i[edit update destroy transfer_ownership]

    def index
      @users = User.order(owner: :desc, role: :desc, email_address: :asc)
    end

    def new
      @user = User.new(role: :employee)
    end

    def create
      @user = User.new(create_params)
      @user.role = sanitized_role(params.dig(:user, :role)) || :employee

      if @user.save
        sync_module_permissions(@user, params[:module_names])
        redirect_to admin_users_path, notice: "User #{@user.email_address} created."
      else
        @selected_module_names = submitted_module_names
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      desired_role = sanitized_role(params.dig(:user, :role))

      # Owner protection happens in the model too, but checking here gives a
      # friendlier error.
      if @user.owner? && desired_role.present? && desired_role != "admin"
        @user.errors.add(:role, "the owner must stay an admin")
        @selected_module_names = submitted_module_names
        return render :edit, status: :unprocessable_entity
      end

      @user.assign_attributes(update_params)
      @user.role = desired_role if desired_role.present? && !@user.owner?

      if @user.save
        sync_module_permissions(@user, params[:module_names])
        redirect_to admin_users_path, notice: "User updated."
      else
        @selected_module_names = submitted_module_names
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      if @user == Current.user
        redirect_to admin_users_path, alert: "You can't delete your own account from this screen."
        return
      end

      if @user.destroy
        redirect_to admin_users_path, notice: "User deleted."
      else
        redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence
      end
    end

    # POST /admin/users/:id/transfer_ownership
    # Hands ownership from the current owner to @user. @user becomes admin
    # automatically; the previous owner stays admin but loses the owner flag.
    def transfer_ownership
      unless Current.user.owner?
        redirect_to admin_users_path, alert: "Only the current owner can transfer ownership."
        return
      end

      if @user == Current.user
        redirect_to edit_admin_user_path(@user), alert: "You already own this workspace."
        return
      end

      User.transaction do
        Current.user.update!(owner: false)
        @user.update!(role: :admin, owner: true)
      end
      redirect_to admin_users_path, notice: "Ownership transferred to #{@user.email_address}."
    rescue ActiveRecord::RecordInvalid => error
      redirect_to edit_admin_user_path(@user), alert: error.message
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def create_params
      params.require(:user).permit(:email_address, :name, :password, :password_confirmation)
    end

    def update_params
      params.require(:user).permit(:email_address, :name)
    end

    # The modules the admin ticked on this submit, so a form re-rendered after a
    # failed save keeps their selection instead of silently reverting to the
    # user's persisted permissions (or none, for a brand-new user) — which would
    # make them re-check every box and risk creating a no-access employee.
    def submitted_module_names
      Array(params[:module_names]).map(&:to_s) & User::MODULES
    end

    # Whitelist role values explicitly — never mass-assigned from params.
    def sanitized_role(value)
      User.roles.key?(value.to_s) ? value.to_s : nil
    end

    # Replaces the user's module set with the new list. Admins get an empty
    # set written (they implicitly have all access via the model anyway).
    def sync_module_permissions(user, module_names)
      return if user.admin?
      desired = Array(module_names).map(&:to_s) & User::MODULES
      current = user.user_module_permissions.pluck(:module_name)

      (desired - current).each { |m| user.user_module_permissions.create!(module_name: m) }
      user.user_module_permissions.where(module_name: current - desired).destroy_all
    end
  end
end
