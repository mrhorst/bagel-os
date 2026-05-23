class LogBookSection < ApplicationRecord
  SECTION_TYPES = %w[long_text short_text number yes_no].freeze

  has_paper_trail ignore: %i[updated_at]

  belongs_to :created_by, class_name: "User", optional: true
  has_many :log_book_responses, dependent: :restrict_with_error

  validates :title, :section_type, presence: true
  validates :section_type, inclusion: { in: SECTION_TYPES }
  validates :position, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :title) }

  def archive!
    update!(active: false)
  end
end
