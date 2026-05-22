class UserModulePermission < ApplicationRecord
  belongs_to :user

  validates :module_name, presence: true,
                          inclusion: { in: User::MODULES },
                          uniqueness: { scope: :user_id }
end
