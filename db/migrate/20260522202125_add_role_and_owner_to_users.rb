class AddRoleAndOwnerToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :role, :integer, null: false, default: 0
    add_column :users, :owner, :boolean, null: false, default: false
    add_index :users, :owner, unique: true, where: "owner = TRUE"
  end
end
