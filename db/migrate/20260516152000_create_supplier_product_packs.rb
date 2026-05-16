class CreateSupplierProductPacks < ActiveRecord::Migration[8.1]
  def change
    create_table :supplier_product_packs do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :product, foreign_key: true
      t.string :raw_sku
      t.string :raw_name
      t.string :purchase_kind, null: false, default: "case"
      t.decimal :units_per_case, precision: 12, scale: 4, null: false
      t.string :inner_unit_label, null: false, default: "unit"
      t.decimal :inner_package_size, precision: 12, scale: 4
      t.string :inner_unit_of_measure
      t.string :standard_unit
      t.string :source, null: false, default: "manual"
      t.string :source_label
      t.datetime :source_snapshot_at
      t.boolean :approved, null: false, default: false
      t.decimal :confidence_score, precision: 5, scale: 2, null: false, default: "0.0"
      t.text :notes
      t.json :raw_data, null: false, default: {}

      t.timestamps
    end

    add_index :supplier_product_packs, [ :supplier_id, :raw_sku ]
    add_index :supplier_product_packs, [ :supplier_id, :raw_name ]
    add_index :supplier_product_packs, [ :product_id, :approved ]

    add_reference :receipt_line_items, :case_pack, foreign_key: { to_table: :supplier_product_packs }
    add_column :receipt_line_items, :inner_quantity, :decimal, precision: 12, scale: 4
    add_column :receipt_line_items, :inner_unit_price, :decimal, precision: 12, scale: 4
    add_column :receipt_line_items, :inner_unit_label, :string

    add_reference :price_observations, :case_pack, foreign_key: { to_table: :supplier_product_packs }
    add_column :price_observations, :inner_quantity, :decimal, precision: 12, scale: 4
    add_column :price_observations, :inner_unit_price, :decimal, precision: 12, scale: 4
    add_column :price_observations, :inner_unit_label, :string
  end
end
