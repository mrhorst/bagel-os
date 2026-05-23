class LogBookResponse < ApplicationRecord
  URGENCIES = %w[normal important urgent].freeze

  has_paper_trail ignore: %i[updated_at]

  belongs_to :log_book_entry
  belongs_to :log_book_section
  belongs_to :follow_up_resolved_by, class_name: "User", optional: true
  belongs_to :last_submitted_by, class_name: "User", optional: true

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

  # Human-friendly rendering of the response value. Numbers respect the
  # decimal precision snapshotted at save time (default 0 = whole numbers)
  # and append the section's unit label when present.
  def display_value
    return "No note today" if no_note?

    case section_type_snapshot
    when "number"
      return "Blank" if value_number.blank?
      formatted = format_number(value_number)
      unit = log_book_section&.unit_label.presence
      unit ? "#{formatted} #{unit}" : formatted
    when "yes_no"
      case value_text
      when "yes" then "Yes"
      when "no"  then "No"
      else "Blank"
      end
    else
      value_text.presence || "Blank"
    end
  end

  private

  def format_number(number)
    decimals = value_decimals_snapshot.to_i.clamp(0, 6)
    if decimals.zero?
      number.to_i.to_s
    else
      format("%.#{decimals}f", number)
    end
  end

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
