class User < ApplicationRecord
  MODULES = %w[
    tasks
    log_book
    follow_ups
    inventory
    recipes
    order_guides
    products
    normalization_reviews
    import_batches
    reports
    marketing
  ].freeze

  has_paper_trail ignore: %i[updated_at]

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :user_module_permissions, dependent: :destroy
  has_many :push_subscriptions, dependent: :destroy

  enum :role, { employee: 0, admin: 1 }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validate :owner_must_be_admin
  before_destroy :prevent_owner_deletion

  def can_access?(module_name)
    return true if admin?
    user_module_permissions.exists?(module_name: module_name.to_s)
  end

  def accessible_modules
    return MODULES if admin?
    user_module_permissions.pluck(:module_name)
  end

  # Idempotent permission writers — used by the admin UI.
  def grant_module(module_name)
    return if admin?
    user_module_permissions.find_or_create_by!(module_name: module_name.to_s)
  end

  def revoke_module(module_name)
    user_module_permissions.where(module_name: module_name.to_s).destroy_all
  end

  private

  def owner_must_be_admin
    errors.add(:role, "owner must be an admin") if owner? && !admin?
  end

  def prevent_owner_deletion
    if owner?
      errors.add(:base, "the owner cannot be deleted; transfer ownership first")
      throw :abort
    end
  end
end
