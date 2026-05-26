class LogBookResponse < ApplicationRecord
  URGENCIES = %w[normal important urgent].freeze

  has_paper_trail ignore: %i[updated_at]

  serialize :value_grid,      coder: JSON
  serialize :fields_snapshot, coder: JSON

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

  def multi?
    section_type_snapshot == "multi"
  end

  def value_grid
    super || {}
  end

  def fields_snapshot
    super || []
  end

  # Human-friendly rendering of the response value. Numbers respect the
  # decimal precision snapshotted at save time (default 0 = whole numbers)
  # and append the section's unit label when present.
  def display_value
    return "No note today" if no_note?

    if multi?
      formatted = fields_snapshot.map { |field| format_grid_entry(field) }.reject(&:blank?)
      return "Blank" if formatted.empty?
      return formatted.join(", ")
    end

    case section_type_snapshot
    when "number"
      return "Blank" if value_number.blank?
      formatted = format_number(value_number, value_decimals_snapshot.to_i)
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

  def format_grid_entry(field)
    key   = field["key"].to_s
    raw   = value_grid[key].to_s
    return nil if raw.blank?

    pretty = case field["type"]
             when "number"
               n = BigDecimal(raw)
               formatted = format_number(n, field["value_decimals"].to_i)
               unit = field["unit_label"].to_s.strip.presence
               unit ? "#{formatted} #{unit}" : formatted
             when "yes_no"
               raw == "yes" ? "Yes" : (raw == "no" ? "No" : nil)
             else
               raw
             end
    return nil if pretty.blank?
    "#{field['label']}: #{pretty}"
  rescue ArgumentError
    nil
  end

  def format_number(number, decimals)
    decimals = decimals.clamp(0, 6)
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

    # Blank is always OK. We only check the shape of values that were
    # actually entered.
    case section_type_snapshot
    when "yes_no"
      return if value_text.blank?
      errors.add(:value_text, "must be Yes or No") unless value_text.in?(%w[yes no])
    when "multi"
      validate_grid_values
    end
  end

  def validate_grid_values
    fields_snapshot.each do |field|
      key = field["key"].to_s
      raw = value_grid[key].to_s
      next if raw.blank?

      case field["type"]
      when "yes_no"
        errors.add(:value_grid, "#{field['label']} must be Yes or No") unless %w[yes no].include?(raw)
      when "number"
        begin
          BigDecimal(raw)
        rescue ArgumentError
          errors.add(:value_grid, "#{field['label']} must be a number")
        end
      end
    end
  end
end
