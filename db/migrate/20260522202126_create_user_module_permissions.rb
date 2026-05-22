class CreateUserModulePermissions < ActiveRecord::Migration[8.1]
  def change
    create_table :user_module_permissions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :module_name, null: false

      t.timestamps
    end

    add_index :user_module_permissions, [ :user_id, :module_name ], unique: true
  end
end
