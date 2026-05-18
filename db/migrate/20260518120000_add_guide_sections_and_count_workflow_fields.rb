class AddGuideSectionsAndCountWorkflowFields < ActiveRecord::Migration[8.1]
  def change
    create_table :order_guide_sections do |t|
      t.references :order_guide, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.text :notes

      t.timestamps
    end
    add_index :order_guide_sections, [ :order_guide_id, :key ], unique: true
    add_index :order_guide_sections, [ :order_guide_id, :active, :position ]

    change_table :order_guide_memberships do |t|
      t.references :order_guide_section, foreign_key: true
      t.string :tracking_mode, null: false, default: "counted"
      t.decimal :expected_usage_quantity, precision: 12, scale: 4
      t.decimal :buffer_quantity, precision: 12, scale: 4
    end

    change_table :inventory_counts do |t|
      t.references :order_guide, foreign_key: true
    end

    change_table :inventory_count_lines do |t|
      t.references :order_guide_membership, foreign_key: true
    end
  end
end
