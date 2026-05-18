class TaskCompletion < ApplicationRecord
  belongs_to :task_occurrence
  belongs_to :staff_member
  belongs_to :undone_by_staff_member,
    class_name: "StaffMember",
    optional: true,
    inverse_of: :undone_task_completions

  has_one_attached :photo

  validates :snapshot_staff_name, :completed_at, presence: true
  validate :photo_matches_occurrence_requirement

  scope :active, -> { where(undone_at: nil) }
  scope :undone, -> { where.not(undone_at: nil) }
  scope :recent_first, -> { order(completed_at: :desc, id: :desc) }

  def active?
    undone_at.blank?
  end

  def undone?
    undone_at.present?
  end

  private

  def photo_matches_occurrence_requirement
    return if task_occurrence.blank?

    if task_occurrence.requires_photo_evidence? && !photo.attached?
      errors.add(:photo, "is required for this task")
    elsif !task_occurrence.requires_photo_evidence? && photo.attached?
      errors.add(:photo, "is only allowed for photo-required tasks")
    end
  end
end
