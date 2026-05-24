class FollowUp < ApplicationRecord
  URGENCIES = %w[normal important urgent].freeze
  STATUSES  = %w[open resolved].freeze
  RESOLUTION_KINDS = %w[action_taken converted_to_task duplicate not_an_issue].freeze

  has_paper_trail ignore: %i[updated_at]

  belongs_to :origin, polymorphic: true, optional: true
  belongs_to :opened_by,   class_name: "User", optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  validates :title, :urgency, :status, :opened_at, presence: true
  validates :urgency, inclusion: { in: URGENCIES }
  validates :status,  inclusion: { in: STATUSES }
  validates :resolved_via, inclusion: { in: RESOLUTION_KINDS, allow_blank: true }

  scope :open,        -> { where(status: "open") }
  scope :resolved,    -> { where(status: "resolved") }
  scope :recent_first, -> { order(opened_at: :desc, id: :desc) }
  scope :by_urgency,  -> {
    order(Arel.sql("CASE urgency WHEN 'urgent' THEN 0 WHEN 'important' THEN 1 ELSE 2 END"), opened_at: :desc)
  }

  def open?;     status == "open";     end
  def resolved?; status == "resolved"; end

  def resolve!(user:, note: nil, via: "action_taken")
    update!(
      status:          "resolved",
      resolved_by:     user,
      resolved_at:     Time.current,
      resolution_note: note.presence,
      resolved_via:    via
    )
  end

  def reopen!(user:)
    update!(
      status:          "open",
      resolved_by:     nil,
      resolved_at:     nil,
      resolution_note: nil,
      resolved_via:    nil
    )
    # opened_by stays as the original opener; we don't overwrite history.
    update!(opened_by: opened_by || user)
  end
end
