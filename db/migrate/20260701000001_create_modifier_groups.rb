class CreateModifierGroups < ActiveRecord::Migration[8.1]
  def change
    create_table :modifier_groups do |t|
      # The label a guest sees for the choice: "Meat", "Cheese", "Bread", "Egg
      # style", "Sides". A group is a reusable, standalone thing — defined once
      # and attached to any number of recipes.
      t.string :name, null: false
      # Whether the choice changes what's used from inventory (and so the cost):
      # "ingredient" options link to inventory items and roll into cost/weight;
      # "preparation" options are prep-only (egg cooking style, "toasted?") and
      # never touch inventory or cost.
      t.string :kind, null: false, default: "ingredient"
      # How many options the guest picks. Pick-one is 1/1; a "2-2-2" style choice
      # is 2/2. Kept as a min/max pair so "pick up to 2" is possible later.
      t.integer :min_select, null: false, default: 1
      t.integer :max_select, null: false, default: 1
      t.integer :position

      t.timestamps
    end

    add_index :modifier_groups, :name, unique: true
  end
end
