class OrderGuideSection < ApplicationRecord
  belongs_to :order_guide
  has_many :order_guide_memberships, dependent: :nullify

  before_validation :assign_key

  validates :name, presence: true
  validates :key, presence: true, uniqueness: { scope: :order_guide_id }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def self.key_for(value)
    value.to_s.downcase.gsub(/&/, " and ").gsub(/[^a-z0-9]+/, " ").squish.parameterize
  end

  private

  def assign_key
    self.key = self.class.key_for(name) if key.blank? && name.present?
  end
end
