class Tag < ApplicationRecord
  has_paper_trail ignore: %i[updated_at]

  has_many :taggings, dependent: :destroy
  has_many :photo_assets, through: :taggings

  before_validation :normalize_slug

  validates :name, presence: true
  # `slug` is the machine value the AI tagger returns, but the form tells admins
  # to "Leave blank to derive it from the name" — so most never touch it. Only
  # check its FORMAT when one is actually present (an admin who typed one), and
  # never scold the blank case: a blank derived slug means the NAME had no usable
  # characters, which #name_yields_usable_slug reports in name terms below.
  # Surfacing a raw "Slug can't be blank" / "Slug must be lowercase…" for a field
  # they were told to leave empty is confusing and contradicts the form's hint.
  validates :slug,
    format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/, message: "must be lowercase words separated by dashes" },
    allow_blank: true
  validate :name_yields_usable_slug
  validate :slug_not_already_used

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  private

  # Derive the machine slug from the name when one isn't given, so admins can
  # just type a label (e.g. "Plated Food" -> "plated-food").
  def normalize_slug
    self.slug = (slug.presence || name).to_s.parameterize
  end

  # A blank *derived* slug means the name had no letters or numbers to build a
  # machine value from — whitespace, an emoji, or a non-latin script (e.g. "🌮"
  # or "料理" both parameterize to ""). The admin was told to leave the slug field
  # blank and never typed one, so a raw "Slug can't be blank" / "Slug must be
  # lowercase…" names a field they have no mental model for and gives no hint that
  # the real problem is their *name*. Speak in name terms on :base (mirrors
  # #slug_not_already_used), and stay silent when the name itself is blank so the
  # "Name can't be blank" error stands alone instead of piling three messages on
  # one mistake.
  def name_yields_usable_slug
    return if slug.present?
    return if name.blank?

    errors.add(:base, %("#{name}" can't be turned into a tag — its name needs letters or numbers. Edit the name, or type a slug.))
  end

  # `slug` is the machine value the AI tagger returns, but the form tells admins
  # to "Leave blank to derive it from the name" — so most of them only ever type
  # a *name* and never touch the slug field. Surfacing a raw "Slug has already
  # been taken" to that person is confusing: they have no mental model for the
  # field the error names, and the message never says which tag actually clashed.
  # A unique DB index still guards the column; here we express the collision in
  # name terms on :base (so it renders without the attribute prefix) and name the
  # existing tag, pointing the admin at what they control. Mirrors
  # OrderGuide#name_not_already_used. Checking the effective (post-normalize)
  # slug covers both the derived-from-name path and an explicitly typed slug, so
  # the unique-index collision never reaches the user as a 500.
  def slug_not_already_used
    return if slug.blank?

    clash = Tag.where(slug: slug)
    clash = clash.where.not(id: id) if persisted?
    existing = clash.first
    return unless existing

    errors.add(:base, %(A tag named "#{existing.name}" already exists. Pick a different name or slug.))
  end
end
