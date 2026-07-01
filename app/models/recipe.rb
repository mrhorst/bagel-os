class Recipe < ApplicationRecord
  # A house recipe — the bridge between purchased products/inventory and eventual
  # menu costing. The first slice is just the record itself; ingredient lines and
  # costing build on top of it (#242, #243).
  has_paper_trail ignore: %i[updated_at]

  has_many :recipe_ingredients, dependent: :destroy
  has_many :inventory_items, through: :recipe_ingredients

  # Reusable choice slots attached to this item (meat, cheese, bread, sides…).
  # The join carries the per-recipe ordering; the groups themselves are shared.
  has_many :recipe_modifier_groups, -> { ordered }, dependent: :destroy, inverse_of: :recipe
  has_many :modifier_groups, through: :recipe_modifier_groups

  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: false }, if: -> { name.present? }
  validates :yield_quantity, numericality: { greater_than: 0 }, allow_nil: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def archived?
    !active?
  end

  # Whether this recipe records how much one batch makes, so per-serving cost
  # and weight can be divided out.
  def yield_described?
    yield_quantity.present? && yield_quantity.positive?
  end
end
