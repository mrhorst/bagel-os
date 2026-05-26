class TaskOccurrence < ApplicationRecord
  PERIOD_KINDS = %w[day month].freeze

  belongs_to :task
  belongs_to :task_list
  has_many :task_completions, dependent: :restrict_with_error
  has_one :active_completion,
    -> { where(undone_at: nil) },
    class_name: "TaskCompletion",
    inverse_of: :task_occurrence
  has_many :undone_completions,
    -> { where.not(undone_at: nil).order(undone_at: :desc, id: :desc) },
    class_name: "TaskCompletion",
    inverse_of: :task_occurrence

  validates :period_kind, :period_starts_on, :period_ends_on, :snapshot_title, :snapshot_list_name, presence: true
  validates :period_kind, inclusion: { in: PERIOD_KINDS }
  validates :task_id, uniqueness: { scope: %i[period_kind period_starts_on] }
  validates :position, numericality: { only_integer: true }
  validate :period_dates_are_ordered

  scope :chronological, -> { order(:period_starts_on, :due_at, :position, :snapshot_title) }
  scope :for_period_range, ->(from_date, to_date) { where("period_starts_on <= ? AND period_ends_on >= ?", to_date, from_date) }
  scope :monthly, -> { where(period_kind: "month") }
  scope :daily, -> { where(period_kind: "day") }

  def status(operating_day: Tasks::OperatingDay.new)
    return "completed" if active_completion.present?
    return "missed" if missed?(operating_day: operating_day)
    return "late" if late?(operating_day: operating_day)

    "open"
  end

  def completed?
    active_completion.present?
  end

  def missed?(operating_day: Tasks::OperatingDay.new)
    active_completion.blank? && operating_day.passed?(completion_window_ends_at)
  end

  def late?(operating_day: Tasks::OperatingDay.new)
    active_completion.blank? && !missed?(operating_day: operating_day) && operating_day.passed?(due_at)
  end

  def open?(operating_day: Tasks::OperatingDay.new)
    status(operating_day: operating_day) == "open"
  end

  def completable?(operating_day: Tasks::OperatingDay.new)
    !missed?(operating_day: operating_day)
  end

  def undoable?(operating_day: Tasks::OperatingDay.new)
    active_completion.present? && operating_day.same_day_as?(active_completion.completed_at)
  end

  def refreshable?(operating_day: Tasks::OperatingDay.new)
    active_completion.blank? && !missed?(operating_day: operating_day)
  end

  def removable_when_task_archived?(operating_day: Tasks::OperatingDay.new)
    refreshable?(operating_day: operating_day)
  end

  # One-time occurrences carry forward (no completion window) until completed.
  # After that, we lock them to the day they were actually completed — they
  # shouldn't keep showing up as "Done" on the dashboard every day after.
  def one_time_carryover?
    completion_window_ends_at.blank?
  end

  def stale_completed_carryover?(operating_day: Tasks::OperatingDay.new)
    return false unless one_time_carryover? && active_completion.present?
    active_completion.completed_at.to_date != operating_day.today
  end

  private

  def period_dates_are_ordered
    return if period_starts_on.blank? || period_ends_on.blank?

    errors.add(:period_ends_on, "must be on or after the period start") if period_ends_on < period_starts_on
  end
end
