class CreateRecipeModifierGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :recipe_modifier_groups do |t|
      # Attaches a reusable modifier group to a recipe. The same group (e.g.
      # "Sides") can be attached to many recipes; position orders the groups
      # within one recipe.
      t.references :recipe, null: false, foreign_key: true
      t.references :modifier_group, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end

    # A group is attached to a recipe at most once.
    add_index :recipe_modifier_groups, %i[recipe_id modifier_group_id], unique: true
  end
end
