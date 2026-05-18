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

  def status(now: Time.current)
    return "completed" if active_completion.present?
    return "missed" if missed?(now: now)
    return "late" if late?(now: now)

    "open"
  end

  def completed?
    active_completion.present?
  end

  def missed?(now: Time.current)
    active_completion.blank? && completion_window_ends_at.present? && now >= completion_window_ends_at
  end

  def late?(now: Time.current)
    active_completion.blank? && !missed?(now: now) && due_at.present? && now >= due_at
  end

  def open?(now: Time.current)
    status(now: now) == "open"
  end

  def completable?(now: Time.current)
    !missed?(now: now)
  end

  def undoable?(now: Time.current)
    active_completion.present? && active_completion.completed_at.to_date == now.to_date
  end

  def refreshable?(now: Time.current)
    active_completion.blank? && !missed?(now: now)
  end

  def removable_when_task_archived?(now: Time.current)
    refreshable?(now: now)
  end

  private

  def period_dates_are_ordered
    return if period_starts_on.blank? || period_ends_on.blank?

    errors.add(:period_ends_on, "must be on or after the period start") if period_ends_on < period_starts_on
  end
end
