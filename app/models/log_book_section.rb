class LogBookSection < ApplicationRecord
  SECTION_TYPES = %w[long_text short_text number yes_no multi].freeze
  FIELD_TYPES   = %w[number short_text yes_no].freeze

  has_paper_trail ignore: %i[updated_at]

  serialize :fields, coder: JSON

  belongs_to :created_by, class_name: "User", optional: true
  has_many :log_book_responses, dependent: :restrict_with_error

  validates :title, :section_type, presence: true
  validates :section_type, inclusion: { in: SECTION_TYPES }
  validates :position, numericality: { only_integer: true }
  validates :value_decimals, numericality: { only_integer: true, in: 0..6 }
  validate  :fields_shape

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :title) }

  def archive!
    update!(active: false)
  end

  def multi?
    section_type == "multi"
  end

  # Always return a usable array — `serialize` gives back nil before the
  # field is ever set, which trips up every consumer.
  def fields
    super || []
  end

  private

  def fields_shape
    return unless multi?
    return errors.add(:fields, "must have at least one input") if fields.empty?

    fields.each_with_index do |entry, idx|
      label = entry["label"].to_s.strip
      type  = entry["type"].to_s
      errors.add(:fields, "row #{idx + 1} needs a label") if label.blank?
      errors.add(:fields, "row #{idx + 1} type is invalid") unless FIELD_TYPES.include?(type)
    end

    # Keys must be unique within a section so value_grid lookups stay sane.
    keys = fields.map { |f| f["key"].to_s }.reject(&:blank?)
    errors.add(:fields, "labels must be unique") if keys.uniq.length != keys.length
  end
end
