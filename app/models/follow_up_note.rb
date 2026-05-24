class FollowUpNote < ApplicationRecord
  has_paper_trail ignore: %i[updated_at]

  belongs_to :follow_up
  belongs_to :author, class_name: "User", optional: true

  validates :body, presence: true
end
