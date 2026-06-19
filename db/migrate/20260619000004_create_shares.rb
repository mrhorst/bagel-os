class CreateShares < ActiveRecord::Migration[8.1]
  # A public, token-addressed link to a collection so someone without an app
  # login (a designer, a printer) can view and download the photos.
  def change
    create_table :shares do |t|
      t.references :collection, null: false, foreign_key: true
      t.string     :token, null: false
      t.datetime   :expires_at
      t.datetime   :revoked_at
      t.integer    :created_by_id

      t.timestamps
    end

    add_index :shares, :token, unique: true
    add_index :shares, :created_by_id
  end
end
