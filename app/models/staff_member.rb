class StaffMember < ApplicationRecord
  has_many :task_completions, dependent: :restrict_with_error
  has_many :undone_task_completions,
    class_name: "TaskCompletion",
    foreign_key: :undone_by_staff_member_id,
    dependent: :nullify,
    inverse_of: :undone_by_staff_member

  validates :display_name, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:display_name) }

  def deactivate!
    update!(active: false)
  end

  def reactivate!
    update!(active: true)
  end
end
