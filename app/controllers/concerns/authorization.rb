module Authorization
  extend ActiveSupport::Concern

  class_methods do
    # Adds a before_action that blocks the action unless the signed-in user
    # has access to the named module. Admins are allowed through implicitly.
    #
    #   require_module_access :tasks, except: :public_health
    def require_module_access(module_name, **options)
      before_action(**options) { ensure_module_access!(module_name) }
    end
  end

  private

  def ensure_module_access!(module_name)
    user = Current.user
    return if user&.admin?
    return if user&.can_access?(module_name)

    flash[:alert] = "You don't have access to that section. Ask an admin for permission."
    redirect_to root_path
  end

  def require_admin!
    return if Current.user&.admin?
    flash[:alert] = "Admins only."
    redirect_to root_path
  end
end
