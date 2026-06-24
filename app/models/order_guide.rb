class OrderGuide < ApplicationRecord
  has_many :order_guide_memberships, dependent: :restrict_with_error
  has_many :inventory_items, through: :order_guide_memberships
  has_many :order_guide_sections, dependent: :destroy

  before_validation :assign_key

  validates :name, presence: true
  validate :name_not_already_used

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def self.key_for(value)
    value.to_s.downcase.gsub(/&/, " and ").gsub(/[^a-z0-9]+/, " ").squish.parameterize
  end

  def self.named!(name)
    find_or_create_by!(key: key_for(name)) do |guide|
      guide.name = name
      guide.position = next_position
      guide.active = true
    end.tap do |guide|
      guide.update!(active: true) unless guide.active?
    end
  end

  def self.name_for_guide_type(guide_type)
    guide_type.to_s.humanize
  end

  def archive!
    update!(active: false)
    order_guide_memberships.active.update_all(active: false, updated_at: Time.current)
  end

  def archived?
    !active?
  end

  def active_memberships
    order_guide_memberships.active
  end

  def active_sections
    order_guide_sections.active.ordered
  end

  def active_item_count
    active_memberships.count
  end

  def section_named!(name)
    section_name = name.presence || "Unsectioned"
    section = order_guide_sections.find_or_initialize_by(key: OrderGuideSection.key_for(section_name))
    section.name = section_name
    section.position = next_section_position if section.new_record? || section.position.blank? || section.position.zero?
    section.active = true
    section.save!
    section
  end

  private

  def assign_key
    self.key = self.class.key_for(name) if key.blank? && name.present?
  end

  # `key` is an internal slug derived from `name` and already guarded by a
  # unique database index. Surfacing its raw "Key has already been taken" /
  # "Key can't be blank" validation errors to a user who only ever typed a
  # *name* is confusing — they have no mental model for a "Key". Express the
  # uniqueness constraint in name terms on :base (so the message renders
  # without the attribute prefix) and let the `name` presence validation cover
  # the blank case. Mirrors the friendly error handling the membership
  # controllers already use. Checks the assigned `key` value (not a fresh
  # slug) so this preserves the existing constraint exactly.
  def name_not_already_used
    return if key.blank?

    clash = OrderGuide.where(key: key)
    clash = clash.where.not(id: id) if persisted?
    existing = clash.first
    return unless existing

    errors.add(:base, %(A guide named "#{existing.name}" already exists. Pick a different name.))
  end

  def self.next_position
    maximum(:position).to_i + 1
  end

  def next_section_position
    order_guide_sections.maximum(:position).to_i + 1
  end
end
