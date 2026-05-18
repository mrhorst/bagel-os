class OrderGuide < ApplicationRecord
  has_many :order_guide_memberships, dependent: :restrict_with_error
  has_many :inventory_items, through: :order_guide_memberships
  has_many :order_guide_sections, dependent: :destroy

  before_validation :assign_key

  validates :name, presence: true
  validates :key, presence: true, uniqueness: true

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

  def self.next_position
    maximum(:position).to_i + 1
  end

  def next_section_position
    order_guide_sections.maximum(:position).to_i + 1
  end
end
