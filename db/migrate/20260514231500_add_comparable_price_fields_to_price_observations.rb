class AddComparablePriceFieldsToPriceObservations < ActiveRecord::Migration[8.1]
  def change
    add_column :price_observations, :presentation_key, :string
    add_column :price_observations, :presentation_label, :string
    add_column :price_observations, :standard_quantity, :decimal, precision: 12, scale: 4
    add_column :price_observations, :unit_confidence, :decimal, precision: 5, scale: 2
    add_column :price_observations, :price_basis, :string, null: false, default: "presentation"
    add_column :price_observations, :needs_unit_review, :boolean, null: false, default: false

    add_index :price_observations, [ :product_id, :presentation_key, :observed_at ], name: "idx_price_obs_product_presentation_date"
    add_index :price_observations, [ :product_id, :standard_unit, :observed_at ], name: "idx_price_obs_product_standard_unit_date"
    add_index :price_observations, :needs_unit_review
  end
end
