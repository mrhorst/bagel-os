class CreateNotificationDispatches < ActiveRecord::Migration[8.1]
  # A small ledger that makes aggregate, condition-based push notifications
  # idempotent. Each row tracks the last notification we sent for a given
  # `kind` (e.g. "normalization_reviews_pending") and the count it covered, so
  # a recurring job can notify only when a backlog genuinely grows rather than
  # re-buzzing every run. One row per kind.
  def change
    create_table :notification_dispatches do |t|
      t.string :kind, null: false
      t.datetime :last_sent_at
      t.integer :last_count, null: false, default: 0
      t.string :last_marker

      t.timestamps
    end

    add_index :notification_dispatches, :kind, unique: true
  end
end
