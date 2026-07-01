class AddYieldToRecipes < ActiveRecord::Migration[8.1]
  def change
    # How much one batch of the recipe makes — e.g. 12 "bagels". Used to divide
    # the recipe's total cost and weight into per-serving figures. Left blank
    # when the yield isn't known.
    add_column :recipes, :yield_quantity, :decimal, precision: 12, scale: 4
    add_column :recipes, :yield_unit, :string
  end
end
