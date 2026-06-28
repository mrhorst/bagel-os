class Recipe < ApplicationRecord
  # A house recipe — the bridge between purchased products/inventory and eventual
  # menu costing. The first slice is just the record itself; ingredient lines and
  # costing build on top of it (#242, #243).
  has_paper_trail ignore: %i[updated_at]

  validates :name, presence: true
  validates :name, uniqueness: { case_sensitive: false }, if: -> { name.present? }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def archived?
    !active?
  end
end
