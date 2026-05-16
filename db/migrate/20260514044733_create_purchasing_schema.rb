class CreatePurchasingSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.text :notes

      t.timestamps
    end
    add_index :suppliers, :name, unique: true

    create_table :product_categories do |t|
      t.string :name, null: false
      t.text :description
      t.integer :sort_order, null: false, default: 0

      t.timestamps
    end
    add_index :product_categories, :name, unique: true

    create_table :import_batches do |t|
      t.references :supplier, null: false, foreign_key: true
      t.string :source_filename, null: false
      t.string :source_path
      t.string :file_checksum, null: false
      t.datetime :imported_at, null: false
      t.string :status, null: false, default: "pending"
      t.integer :rows_processed, null: false, default: 0
      t.integer :rows_imported, null: false, default: 0
      t.integer :rows_failed, null: false, default: 0
      t.text :notes
      t.json :validation_summary, null: false, default: {}

      t.timestamps
    end
    add_index :import_batches, :file_checksum, unique: true
    add_index :import_batches, [ :supplier_id, :source_filename ]
    add_index :import_batches, :status

    create_table :receipts do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :import_batch, null: false, foreign_key: true
      t.string :receipt_number, null: false
      t.datetime :purchased_at
      t.decimal :subtotal, precision: 12, scale: 2
      t.decimal :tax, precision: 12, scale: 2
      t.decimal :total, precision: 12, scale: 2
      t.json :raw_data, null: false, default: {}

      t.timestamps
    end
    add_index :receipts, [ :supplier_id, :receipt_number ], unique: true
    add_index :receipts, :purchased_at

    create_table :products do |t|
      t.references :supplier, null: false, foreign_key: true
      t.references :product_category, foreign_key: true
      t.string :canonical_name, null: false
      t.string :supplier_sku
      t.string :purchase_unit
      t.decimal :package_size, precision: 12, scale: 4
      t.string :unit_of_measure
      t.string :standard_unit
      t.text :notes
      t.boolean :active, null: false, default: true
      t.boolean :needs_review, null: false, default: true

      t.timestamps
    end
    add_index :products, [ :supplier_id, :supplier_sku ], unique: true, where: "supplier_sku IS NOT NULL"
    add_index :products, :canonical_name
    add_index :products, :needs_review

    create_table :receipt_line_items do |t|
      t.references :receipt, null: false, foreign_key: true
      t.references :supplier, null: false, foreign_key: true
      t.references :import_batch, null: false, foreign_key: true
      t.references :product, foreign_key: true
      t.integer :line_number, null: false
      t.string :line_type, null: false, default: "item"
      t.string :raw_name, null: false
      t.string :raw_sku
      t.string :raw_quantity
      t.string :raw_case_quantity
      t.string :raw_unit
      t.string :raw_package_description
      t.decimal :quantity, precision: 12, scale: 4
      t.decimal :package_price, precision: 12, scale: 4
      t.decimal :line_total, precision: 12, scale: 2
      t.decimal :parsed_package_size, precision: 12, scale: 4
      t.string :parsed_unit_of_measure
      t.decimal :confidence_score, precision: 5, scale: 2, null: false, default: 0
      t.boolean :needs_review, null: false, default: true
      t.string :row_checksum, null: false
      t.json :raw_data, null: false, default: {}

      t.timestamps
    end
    add_index :receipt_line_items, [ :import_batch_id, :line_number ], unique: true
    add_index :receipt_line_items, :raw_sku
    add_index :receipt_line_items, :line_type
    add_index :receipt_line_items, :needs_review
    add_index :receipt_line_items, :row_checksum

    create_table :product_aliases do |t|
      t.references :product, null: false, foreign_key: true
      t.string :raw_name, null: false
      t.string :raw_sku
      t.decimal :confidence_score, precision: 5, scale: 2, null: false, default: 0
      t.boolean :approved, null: false, default: false

      t.timestamps
    end
    add_index :product_aliases, [ :product_id, :raw_name, :raw_sku ], unique: true
    add_index :product_aliases, :raw_sku
    add_index :product_aliases, :approved

    create_table :price_observations do |t|
      t.references :product, null: false, foreign_key: true
      t.references :receipt_line_item, null: false, foreign_key: true, index: { unique: true }
      t.references :supplier, null: false, foreign_key: true
      t.datetime :observed_at, null: false
      t.decimal :package_price, precision: 12, scale: 4
      t.decimal :quantity, precision: 12, scale: 4
      t.decimal :line_total, precision: 12, scale: 2
      t.decimal :unit_price, precision: 12, scale: 4
      t.decimal :standard_unit_price, precision: 12, scale: 4
      t.string :standard_unit
      t.decimal :package_size, precision: 12, scale: 4
      t.string :unit_of_measure
      t.string :source_filename, null: false
      t.text :notes
      t.boolean :possible_price_spike, null: false, default: false
      t.decimal :percent_above_recent_average, precision: 8, scale: 2

      t.timestamps
    end
    add_index :price_observations, [ :product_id, :observed_at ]
    add_index :price_observations, :possible_price_spike

    create_table :normalization_reviews do |t|
      t.references :receipt_line_item, null: false, foreign_key: true
      t.references :product, foreign_key: true
      t.string :issue_type, null: false
      t.text :description, null: false
      t.string :status, null: false, default: "pending"
      t.text :resolution_notes

      t.timestamps
    end
    add_index :normalization_reviews, :issue_type
    add_index :normalization_reviews, :status
  end
end
