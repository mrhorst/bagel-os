class FollowUpTaskLink < ApplicationRecord
  LINK_KINDS = %w[one_shot recurring].freeze

  has_paper_trail ignore: %i[updated_at]

  belongs_to :follow_up
  belongs_to :task
  belongs_to :created_by, class_name: "User", optional: true

  validates :link_kind, inclusion: { in: LINK_KINDS }
  validates :follow_up_id, uniqueness: { scope: :task_id }
end
