require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")
    assert_equal("downcased@example.com", user.email_address)
  end

  test "admins implicitly can access every module" do
    admin = users(:one)
    assert admin.admin?
    User::MODULES.each { |m| assert admin.can_access?(m), "admin should access #{m}" }
  end

  test "employees only access modules they were granted" do
    employee = users(:two)
    refute employee.can_access?("tasks")

    employee.grant_module("tasks")
    assert employee.can_access?("tasks")
    refute employee.can_access?("inventory")
  end

  test "grant_module is a no-op for admins" do
    admin = users(:one)
    assert_no_difference -> { UserModulePermission.count } do
      admin.grant_module("tasks")
    end
  end

  test "owner cannot be deleted" do
    owner = users(:one)
    assert owner.owner?
    assert_no_difference -> { User.count } do
      owner.destroy
    end
    assert_includes owner.errors[:base], "the owner cannot be deleted; transfer ownership first"
  end

  test "owner must be an admin" do
    user = users(:two)
    user.owner = true
    user.role = :employee
    refute user.valid?
    assert_includes user.errors[:role], "owner must be an admin"
  end
end
