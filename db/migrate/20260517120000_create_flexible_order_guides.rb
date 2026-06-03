class CreateFlexibleOrderGuides < ActiveRecord::Migration[8.1]
  def change
    create_table :order_guides do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.text :notes

      t.timestamps
    end
    add_index :order_guides, :key, unique: true
    add_index :order_guides, [ :active, :position ]

    create_table :order_guide_memberships do |t|
      t.references :order_guide, null: false, foreign_key: true
      t.references :inventory_item, null: false, foreign_key: true
      t.references :preferred_supplier, foreign_key: { to_table: :suppliers }
      t.boolean :primary_guide, null: false, default: false
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0
      t.decimal :par, precision: 12, scale: 4
      t.decimal :reorder_point, precision: 12, scale: 4
      t.text :notes

      t.timestamps
    end
    add_index :order_guide_memberships,
      [ :order_guide_id, :inventory_item_id ],
      unique: true,
      name: "idx_order_guide_memberships_unique_guide_item"
    add_index :order_guide_memberships,
      [ :inventory_item_id, :primary_guide ],
      unique: true,
      where: "active = TRUE AND primary_guide = TRUE",
      name: "idx_order_guide_memberships_one_active_primary"
    add_index :order_guide_memberships,
      [ :order_guide_id, :active, :position ],
      name: "idx_order_guide_memberships_on_guide_active_position"
  end
end
