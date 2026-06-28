class CreateRecipes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipes do |t|
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :position

      t.timestamps
    end

    add_index :recipes, :name
  end
end
