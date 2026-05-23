class LogBookResponse < ApplicationRecord
  URGENCIES = %w[normal important urgent].freeze

  has_paper_trail ignore: %i[updated_at]

  belongs_to :log_book_entry
  belongs_to :log_book_section
  belongs_to :follow_up_resolved_by, class_name: "User", optional: true

  validates :section_title_snapshot, :section_type_snapshot, :urgency, presence: true
  validates :urgency, inclusion: { in: URGENCIES }
  validates :log_book_section_id, uniqueness: { scope: :log_book_entry_id }
  validate :value_matches_section_type

  scope :flagged, -> { where(flagged_for_follow_up: true) }
  scope :unresolved, -> { flagged.where(follow_up_resolved_at: nil) }
  scope :recent_first, -> { joins(:log_book_entry).order("log_book_entries.operating_date DESC", created_at: :desc) }

  def resolve!(user:)
    update!(follow_up_resolved_at: Time.current, follow_up_resolved_by: user)
  end

  def display_value
    return "No note today" if no_note?
    return value_number.to_s if section_type_snapshot == "number"

    value_text.presence || "Blank"
  end

  private

  def value_matches_section_type
    if no_note? && !log_book_section&.allow_no_note?
      errors.add(:no_note, "is not allowed for this section")
      return
    end

    return if no_note?

    case section_type_snapshot
    when "number"
      errors.add(:value_number, "is required") if value_number.blank?
    when "yes_no"
      errors.add(:value_text, "must be Yes or No") unless value_text.in?(%w[yes no])
    else
      errors.add(:value_text, "is required") if value_text.blank?
    end
  end
end
