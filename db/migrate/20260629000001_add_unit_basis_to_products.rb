class AddUnitBasisToProducts < ActiveRecord::Migration[8.1]
  def change
    # How this product is used: by count (eggs), by weight (corned beef hash),
    # or by volume. Left null when unknown — we never guess it.
    add_column :products, :unit_basis, :string

    # An optional bridge from a counted product to a weight: the average weight
    # of one "each" (e.g. one egg ≈ 50 g). Lets a counted ingredient contribute
    # to a recipe's total weight and lets count↔weight costing convert safely.
    # Both columns are filled together or left blank.
    add_column :products, :each_weight_value, :decimal, precision: 12, scale: 4
    add_column :products, :each_weight_unit, :string

    add_index :products, :unit_basis
  end
end
