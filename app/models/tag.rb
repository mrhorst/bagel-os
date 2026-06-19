class Tag < ApplicationRecord
  has_paper_trail ignore: %i[updated_at]

  has_many :taggings, dependent: :destroy
  has_many :photo_assets, through: :taggings

  before_validation :normalize_slug

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must be lowercase words separated by dashes" }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  private

  # Derive the machine slug from the name when one isn't given, so admins can
  # just type a label (e.g. "Plated Food" -> "plated-food").
  def normalize_slug
    self.slug = (slug.presence || name).to_s.parameterize
  end
end
