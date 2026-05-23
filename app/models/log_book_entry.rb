class LogBookEntry < ApplicationRecord
  has_paper_trail ignore: %i[updated_at]

  belongs_to :submitted_by, class_name: "User", optional: true
  has_many :log_book_responses, dependent: :destroy

  validates :operating_date, presence: true, uniqueness: true

  scope :recent_first, -> { order(operating_date: :desc) }

  # An entry is editable only on its own operating day. We accept either a
  # Tasks::OperatingDay or a Date so model tests don't need the service.
  def editable?(operating_day: Tasks::OperatingDay.new)
    today = operating_day.respond_to?(:today) ? operating_day.today : operating_day
    operating_date == today
  end
end
