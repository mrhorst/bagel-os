class CreateRecipeIngredients < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_ingredients do |t|
      t.references :recipe, null: false, foreign_key: true
      # Optional: a line may reference an existing inventory item, or carry a
      # free-text name for something not (yet) tracked in inventory.
      t.references :inventory_item, foreign_key: true
      t.string :name
      # Amount and unit are explicit, free-form fields. We never infer a unit or
      # conversion — an unknown amount/unit stays blank rather than guessed.
      t.decimal :quantity, precision: 12, scale: 4
      t.string :unit
      t.integer :position

      t.timestamps
    end
  end
end
