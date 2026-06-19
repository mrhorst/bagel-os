class AddLateNotifiedAtToTaskOccurrences < ActiveRecord::Migration[8.1]
  # Records the moment we pushed a "task is late" notification for an
  # occurrence, so the recurring late-task sweep never announces the same late
  # task twice. Naturally null on each new day's freshly-built occurrence row
  # (occurrences are keyed by period_starts_on), so the marker resets per day.
  def change
    add_column :task_occurrences, :late_notified_at, :datetime
    add_index :task_occurrences, :late_notified_at
  end
end
