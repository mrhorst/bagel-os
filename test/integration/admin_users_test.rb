require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  test "non-admins are bounced from the admin section" do
    sign_in_as(users(:two))
    get admin_users_path
    assert_redirected_to root_path
  end

  test "admin sees the users list" do
    get admin_users_path
    assert_response :success
    assert_match users(:one).email_address, response.body
    assert_match "Owner", response.body
  end

  test "admin creates an employee with module permissions" do
    assert_difference -> { User.count } => 1, -> { UserModulePermission.count } => 2 do
      post admin_users_path, params: {
        user: {
          email_address: "new-employee@example.com",
          name: "New Hire",
          role: "employee",
          password: "secret123",
          password_confirmation: "secret123"
        },
        module_names: %w[tasks inventory]
      }
    end

    user = User.find_by!(email_address: "new-employee@example.com")
    assert user.employee?
    assert user.can_access?("tasks")
    assert user.can_access?("inventory")
    refute user.can_access?("products")
  end

  test "admin updates an employee's modules" do
    employee = users(:two)
    employee.grant_module("tasks")

    patch admin_user_path(employee), params: {
      user: { email_address: employee.email_address, name: employee.name, role: "employee" },
      module_names: %w[inventory order_guides]
    }

    assert_redirected_to admin_users_path
    employee.reload
    refute employee.can_access?("tasks")
    assert employee.can_access?("inventory")
    assert employee.can_access?("order_guides")
  end

  test "a failed create keeps the admin's module selections checked" do
    assert_no_difference -> { User.count } do
      post admin_users_path, params: {
        user: {
          email_address: "typo@example.com",
          name: "Typo Hire",
          role: "employee",
          password: "secret123",
          password_confirmation: "secretXYZ" # mismatch → validation fails
        },
        module_names: %w[tasks inventory]
      }
    end

    assert_response :unprocessable_entity
    # The re-rendered form must keep the modules the admin already ticked, so
    # they don't have to re-check them (and risk creating a no-access user).
    assert_select "input[type=checkbox][name='module_names[]'][value=tasks][checked]"
    assert_select "input[type=checkbox][name='module_names[]'][value=inventory][checked]"
    # …and must not check a module the admin did not pick.
    assert_select "input[type=checkbox][name='module_names[]'][value=products][checked]", false
  end

  test "admin cannot demote the owner" do
    patch admin_user_path(users(:one)), params: {
      user: { email_address: users(:one).email_address, role: "employee" }
    }

    assert_response :unprocessable_entity
    assert users(:one).reload.admin?
    assert users(:one).owner?
  end

  test "owner can transfer ownership" do
    target = users(:two)
    post transfer_ownership_admin_user_path(target)

    assert_redirected_to admin_users_path
    target.reload
    refute users(:one).reload.owner?
    assert users(:one).admin?, "previous owner stays admin"
    assert target.owner?
    assert target.admin?
  end

  test "non-owner admin cannot transfer ownership" do
    # Promote :two to admin (still not owner) then try to transfer
    promoted = users(:two).tap { |u| u.update!(role: :admin) }
    sign_in_as(promoted)

    post transfer_ownership_admin_user_path(promoted)
    assert_redirected_to admin_users_path
    follow_redirect!
    assert_match "Only the current owner can transfer ownership.", response.body
  end

  test "deleting the owner is blocked" do
    delete admin_user_path(users(:one))
    assert_redirected_to admin_users_path
    assert User.exists?(users(:one).id)
  end

  test "admin deletes another user" do
    target = users(:two)
    assert_difference -> { User.count } => -1 do
      delete admin_user_path(target)
    end
    assert_redirected_to admin_users_path
  end
end
