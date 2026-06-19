class Collection < ApplicationRecord
  # An album/campaign grouping of photo assets — e.g. "Summer menu shoot" or
  # "Instagram ready". Orthogonal to tags: a photo can sit in many collections
  # and carry many tags at once.
  has_paper_trail ignore: %i[updated_at]

  belongs_to :created_by, class_name: "User", optional: true

  has_many :collection_memberships, dependent: :destroy
  has_many :photo_assets, through: :collection_memberships

  before_validation :normalize_slug

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true,
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must be lowercase words separated by dashes" }

  scope :ordered, -> { order(:position, :name) }

  # The most recent photo in the collection, used as the cover thumbnail.
  def cover_asset
    photo_assets.with_attached_photo.order(created_at: :desc, id: :desc).first
  end

  private

  # Derive the machine slug from the name when one isn't given, so admins can
  # just type a label (e.g. "Summer Menu" -> "summer-menu").
  def normalize_slug
    self.slug = (slug.presence || name).to_s.parameterize
  end
end
