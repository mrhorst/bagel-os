class LogBookEntry < ApplicationRecord
  has_paper_trail ignore: %i[updated_at]

  belongs_to :submitted_by, class_name: "User", optional: true
  has_many :log_book_responses, dependent: :destroy

  validates :operating_date, presence: true, uniqueness: true

  scope :recent_first, -> { order(operating_date: :desc) }

  def editable?(today: Time.zone.today)
    operating_date == today
  end
end
