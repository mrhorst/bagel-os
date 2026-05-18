class Task < ApplicationRecord
  RECURRENCE_TYPES = %w[one_time daily weekly monthly].freeze

  belongs_to :task_list
  has_many :task_occurrences, dependent: :restrict_with_error

  validates :title, :recurrence_type, presence: true
  validates :recurrence_type, inclusion: { in: RECURRENCE_TYPES }
  validates :position, numericality: { only_integer: true }
  validate :schedule_shape_is_valid

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :title) }

  def archive!
    transaction do
      update!(active: false)
      task_occurrences.includes(:active_completion).find_each do |occurrence|
        occurrence.destroy! if occurrence.removable_when_task_archived?
      end
    end
  end

  def reactivate!
    update!(active: true)
  end

  def archived?
    !active?
  end

  def weekly?
    recurrence_type == "weekly"
  end

  def daily?
    recurrence_type == "daily"
  end

  def monthly?
    recurrence_type == "monthly"
  end

  def one_time?
    recurrence_type == "one_time"
  end

  def weekday_values
    Array(weekdays).map(&:to_i).uniq.sort
  end

  private

  def schedule_shape_is_valid
    case recurrence_type
    when "one_time"
      errors.add(:one_time_on, "is required") if one_time_on.blank?
      errors.add(:due_time, "is required") if due_time.blank?
    when "daily"
      errors.add(:starts_on, "is required") if starts_on.blank?
      errors.add(:due_time, "is required") if due_time.blank?
    when "weekly"
      errors.add(:starts_on, "is required") if starts_on.blank?
      errors.add(:due_time, "is required") if due_time.blank?
      errors.add(:weekdays, "must include at least one day") if weekday_values.empty?
      errors.add(:weekdays, "must be integers from 0 to 6") if weekday_values.any? { |day| day.negative? || day > 6 }
    when "monthly"
      errors.add(:starts_on, "is required") if starts_on.blank?
    end

    if starts_on.present? && ends_on.present? && ends_on < starts_on
      errors.add(:ends_on, "must be on or after the start date")
    end
  end
end
