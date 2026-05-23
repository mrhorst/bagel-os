require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  test "employee without permissions is redirected away from tasks" do
    sign_in_as(users(:two))
    get tasks_root_path
    assert_redirected_to root_path
  end

  test "employee with tasks permission can reach the tasks dashboard" do
    employee = users(:two)
    employee.grant_module("tasks")
    sign_in_as(employee)

    get tasks_root_path
    assert_response :success
  end

  test "employee with tasks permission cannot reach order guides" do
    employee = users(:two)
    employee.grant_module("tasks")
    sign_in_as(employee)

    get order_guides_path
    assert_redirected_to root_path
  end

  test "admin reaches every module" do
    sign_in_as(users(:one))
    [ tasks_root_path, log_book_path, order_guides_path, products_path,
      inventory_path, import_batches_path,
      normalization_reviews_path, reports_path ].each do |path|
      get path
      assert_response :success, "expected success at #{path}, got #{response.status}"
    end
  end

  test "dashboard is visible to any signed-in user" do
    sign_in_as(users(:two))
    get root_path
    assert_response :success
  end
end
