class AddUnitAndCaseQuantitiesToPurchasing < ActiveRecord::Migration[8.1]
  def change
    add_column :receipt_line_items, :unit_quantity, :decimal, precision: 12, scale: 4
    add_column :receipt_line_items, :case_quantity, :decimal, precision: 12, scale: 4
    add_column :price_observations, :unit_quantity, :decimal, precision: 12, scale: 4
    add_column :price_observations, :case_quantity, :decimal, precision: 12, scale: 4
    add_column :price_observations, :purchase_kind, :string

    add_index :price_observations, [ :product_id, :purchase_kind, :observed_at ], name: "idx_price_obs_product_purchase_kind_date"
  end
end
