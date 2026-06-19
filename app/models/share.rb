class Share < ApplicationRecord
  # A public link to a collection. The token is the only credential, so it's
  # generated unguessably and the link can be revoked or given an expiry.
  belongs_to :collection
  belongs_to :created_by, class_name: "User", optional: true

  has_secure_token :token, length: 24

  scope :active, -> { where(revoked_at: nil) }

  def expired?
    expires_at.present? && expires_at.past?
  end

  def revoked?
    revoked_at.present?
  end

  # Usable links resolve to the public gallery; revoked or expired ones 404.
  def usable?
    !revoked? && !expired?
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
