class CreatePushSubscriptions < ActiveRecord::Migration[8.1]
  def change
    create_table :push_subscriptions do |t|
      t.references :user, null: false, foreign_key: true

      # What the browser handed us when it subscribed: the push-service endpoint
      # URL for this device, plus the two keys needed to encrypt payloads for it
      # (RFC 8291). One row == one browser/device subscription.
      t.string :endpoint,   null: false
      t.string :p256dh_key, null: false
      t.string :auth_key,   null: false

      # Helps a user recognise which device a subscription belongs to.
      t.string :user_agent

      t.timestamps
    end

    # The endpoint uniquely identifies a subscription; re-subscribing the same
    # device should update, not duplicate.
    add_index :push_subscriptions, :endpoint, unique: true
  end
end
