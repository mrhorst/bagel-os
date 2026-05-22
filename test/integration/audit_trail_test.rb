require "test_helper"

class AuditTrailTest < ActionDispatch::IntegrationTest
  test "updating a user through the admin UI records a version with whodunnit" do
    target = users(:two)

    assert_difference -> { target.versions.count } => 1 do
      patch admin_user_path(target), params: {
        user: { email_address: target.email_address, name: "Renamed Person", role: "employee" }
      }
    end

    version = target.versions.last
    assert_equal users(:one).id.to_s, version.whodunnit
    assert_equal "update", version.event
  end

  test "granting a module permission records a version" do
    employee = users(:two)

    assert_difference -> { PaperTrail::Version.where(item_type: "UserModulePermission").count } => 1 do
      patch admin_user_path(employee), params: {
        user: { email_address: employee.email_address, name: employee.name, role: "employee" },
        module_names: %w[tasks]
      }
    end

    permission = employee.user_module_permissions.sole
    version = PaperTrail::Version.where(item_type: "UserModulePermission", item_id: permission.id).sole
    assert_equal users(:one).id.to_s, version.whodunnit
    assert_equal "create", version.event
  end
end
