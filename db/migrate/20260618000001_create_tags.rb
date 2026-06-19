class CreateTags < ActiveRecord::Migration[8.1]
  def change
    create_table :tags do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.text    :instruction
      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :tags, :slug, unique: true
    add_index :tags, :active
  end
end
