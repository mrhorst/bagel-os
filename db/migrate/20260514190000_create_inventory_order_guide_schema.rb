class CreateInventoryOrderGuideSchema < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_sections do |t|
      t.string :name, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end
    add_index :inventory_sections, :name, unique: true

    create_table :inventory_items do |t|
      t.references :product, foreign_key: true
      t.references :inventory_section, foreign_key: true
      t.references :preferred_supplier, foreign_key: { to_table: :suppliers }
      t.string :name, null: false
      t.string :key, null: false
      t.string :category
      t.string :subcategory
      t.string :count_unit
      t.string :pack_size
      t.decimal :current_par, precision: 12, scale: 4
      t.decimal :reorder_point, precision: 12, scale: 4
      t.string :guide_frequency, null: false, default: "manual"
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.boolean :needs_review, null: false, default: false
      t.text :notes
      t.json :raw_data, null: false, default: {}

      t.timestamps
    end
    add_index :inventory_items, :key, unique: true
    add_index :inventory_items, :guide_frequency
    add_index :inventory_items, :needs_review
    add_index :inventory_items, [ :inventory_section_id, :position ]

    create_table :inventory_counts do |t|
      t.references :inventory_section, foreign_key: true
      t.string :source, null: false, default: "manual"
      t.string :status, null: false, default: "completed"
      t.datetime :counted_at, null: false
      t.datetime :completed_at
      t.text :notes
      t.json :raw_data, null: false, default: {}

      t.timestamps
    end
    add_index :inventory_counts, :counted_at
    add_index :inventory_counts, :status

    create_table :inventory_count_lines do |t|
      t.references :inventory_count, null: false, foreign_key: true
      t.references :inventory_item, null: false, foreign_key: true
      t.decimal :quantity_on_hand, precision: 12, scale: 4, null: false
      t.string :unit
      t.string :presentation
      t.text :raw_text
      t.decimal :confidence, precision: 5, scale: 2, null: false, default: 1.0
      t.text :notes

      t.timestamps
    end
    add_index :inventory_count_lines, [ :inventory_count_id, :inventory_item_id ], name: "idx_inventory_count_lines_on_count_and_item"

    create_table :order_guide_imports do |t|
      t.string :source_filename, null: false
      t.string :source_path
      t.string :guide_type, null: false
      t.string :file_checksum, null: false
      t.datetime :imported_at, null: false
      t.string :status, null: false, default: "pending"
      t.integer :rows_imported, null: false, default: 0
      t.text :raw_text
      t.text :notes
      t.json :validation_summary, null: false, default: {}

      t.timestamps
    end
    add_index :order_guide_imports, :file_checksum, unique: true
    add_index :order_guide_imports, [ :guide_type, :imported_at ]
    add_index :order_guide_imports, :status

    create_table :order_guide_items do |t|
      t.references :order_guide_import, null: false, foreign_key: true
      t.references :inventory_item, foreign_key: true
      t.string :guide_type, null: false
      t.string :section_name, null: false
      t.string :subcategory
      t.string :item_name, null: false
      t.string :guide_sku
      t.string :par_text
      t.string :pack_quantity
      t.string :sunday_target
      t.string :thursday_target
      t.text :raw_line, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.boolean :needs_review, null: false, default: false
      t.decimal :match_confidence, precision: 5, scale: 2, null: false, default: 0.0
      t.json :raw_data, null: false, default: {}

      t.timestamps
    end
    add_index :order_guide_items, [ :guide_type, :active ]
    add_index :order_guide_items, [ :section_name, :position ]
    add_index :order_guide_items, :needs_review
  end
end
