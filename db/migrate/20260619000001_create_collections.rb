class CreateCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :collections do |t|
      t.string  :name, null: false
      t.string  :slug, null: false
      t.text    :description
      t.integer :position, null: false, default: 0
      t.integer :created_by_id

      t.timestamps
    end

    add_index :collections, :slug, unique: true
    add_index :collections, :created_by_id
  end
end
