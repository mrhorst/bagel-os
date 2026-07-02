class CreateModifierOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :modifier_options do |t|
      t.references :modifier_group, null: false, foreign_key: true
      # Shaped like a recipe line: it prefers a tracked inventory item (so the
      # option stays traceable to purchasing and pricing) but can also be a
      # free-text name for a prep-only choice ("over medium") or something not
      # tracked in inventory.
      t.references :inventory_item, null: true, foreign_key: true
      t.string :name
      # The amount this option contributes ("2 slices", "1 each"). Explicit and
      # free-form — an unknown amount/unit stays blank rather than guessed.
      t.decimal :quantity, precision: 12, scale: 4
      t.string :unit
      # The standard pick for this group (over medium, bagel). Drives the
      # "standard configuration" shown in the cost/weight estimate.
      t.boolean :default_choice, null: false, default: false
      t.integer :position

      t.timestamps
    end
  end
end
