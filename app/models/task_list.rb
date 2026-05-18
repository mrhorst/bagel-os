class TaskList < ApplicationRecord
  has_many :tasks, dependent: :restrict_with_error
  has_many :task_occurrences, dependent: :restrict_with_error

  before_validation :assign_key

  validates :name, presence: true
  validates :key, presence: true, uniqueness: true
  validates :position, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def self.key_for(value)
    value.to_s.downcase.gsub(/&/, " and ").gsub(/[^a-z0-9]+/, " ").squish.parameterize
  end

  def archive!
    transaction do
      update!(active: false)
      tasks.active.find_each(&:archive!)
    end
  end

  def reactivate!
    update!(active: true)
  end

  def archived?
    !active?
  end

  def visible_at?(time = Time.current)
    return true if display_start_time.blank? && display_end_time.blank?

    current_seconds = seconds_since_midnight(time)
    start_seconds = display_start_time.present? ? seconds_since_midnight(display_start_time) : nil
    end_seconds = display_end_time.present? ? seconds_since_midnight(display_end_time) : nil

    return current_seconds >= start_seconds if end_seconds.blank?
    return current_seconds <= end_seconds if start_seconds.blank?
    return current_seconds.between?(start_seconds, end_seconds) if start_seconds <= end_seconds

    current_seconds >= start_seconds || current_seconds <= end_seconds
  end

  def display_window?
    display_start_time.present? || display_end_time.present?
  end

  private

  def assign_key
    self.key = self.class.key_for(name) if key.blank? && name.present?
  end

  def seconds_since_midnight(value)
    (value.hour * 60 * 60) + (value.min * 60) + value.sec
  end
end
