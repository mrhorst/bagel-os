class TaskCompletion < ApplicationRecord
  belongs_to :task_occurrence
  # New completions reference user; legacy rows still reference staff_member.
  belongs_to :user, optional: true
  belongs_to :staff_member, optional: true
  belongs_to :undone_by_user,
    class_name: "User",
    optional: true
  belongs_to :undone_by_staff_member,
    class_name: "StaffMember",
    optional: true,
    inverse_of: :undone_task_completions

  has_one_attached :photo

  validates :snapshot_staff_name, :completed_at, presence: true
  validate :photo_matches_occurrence_requirement
  validate :completer_present

  def completed_by
    user || staff_member
  end

  def undone_by
    undone_by_user || undone_by_staff_member
  end

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

  def completer_present
    errors.add(:base, "must have a user or staff member") if user_id.blank? && staff_member_id.blank?
  end

  def photo_matches_occurrence_requirement
    return if task_occurrence.blank?

    if task_occurrence.requires_photo_evidence? && !photo.attached?
      errors.add(:photo, "is required for this task")
    elsif !task_occurrence.requires_photo_evidence? && photo.attached?
      errors.add(:photo, "is only allowed for photo-required tasks")
    end
  end
end
