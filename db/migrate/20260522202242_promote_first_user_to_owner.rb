class PromoteFirstUserToOwner < ActiveRecord::Migration[8.1]
  # If there are existing users but no owner yet, promote the earliest-created
  # user to admin + owner so the install always has someone with full access.
  def up
    return if User.where(owner: true).exists?
    first = User.order(:created_at, :id).first
    return unless first
    first.update_columns(role: 1, owner: true)
  end

  def down
    # No-op: we don't unset ownership on rollback.
  end
end
