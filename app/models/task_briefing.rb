class TaskBriefing < ApplicationRecord
  validates :scope_type, :scope_key, :generated_at, :input_digest, :headline, :next_action, presence: true

  scope :recent_first, -> { order(generated_at: :desc, id: :desc) }

  def priority_items
    Array(super)
  end

  def source_task_occurrence_ids
    Array(super)
  end
end
