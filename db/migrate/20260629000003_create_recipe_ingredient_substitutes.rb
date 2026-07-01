class CreateRecipeIngredientSubstitutes < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_ingredient_substitutes do |t|
      t.references :recipe_ingredient, null: false, foreign_key: true
      # Like a recipe line, a substitute prefers a tracked inventory item but can
      # also be a free-text name for something not in inventory.
      t.references :inventory_item, null: true, foreign_key: true
      t.string :name
      # Its own amount, used when the substitute isn't a 1:1 swap (e.g. 3 tbsp
      # aquafaba for 1 egg). Left blank to mean "same amount as the line".
      t.decimal :quantity, precision: 12, scale: 4
      t.string :unit
      t.string :note
      t.integer :position

      t.timestamps
    end
  end
end
