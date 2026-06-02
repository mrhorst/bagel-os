require "test_helper"

# An employee should only ever see what they've been granted: the dashboard
# surface cards, the desktop sidebar, and the mobile bottom-tab hubs are all
# scoped to their module permissions.
class NavigationScopingTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true

  setup do
    load Rails.root.join("db/seeds.rb")
    @employee = users(:two)
    @employee.grant_module("tasks")
    @employee.grant_module("follow_ups")
  end

  test "dashboard only renders surface cards the employee can access" do
    sign_in_as(@employee)
    get root_path

    assert_response :success
    assert_select ".home-surface-card-label", text: "Tasks"
    %w[Log\ Book Review\ queue Order\ guides Inventory Products].each do |label|
      assert_select ".home-surface-card-label", text: label, count: 0
    end
  end

  test "mobile bottom tabs only show hubs with an accessible module" do
    sign_in_as(@employee)
    get root_path

    assert_response :success
    # Shift (Tasks, Follow-ups) and More (Account, always reachable) stay;
    # Stock and Buying have no granted modules and drop out.
    assert_select ".mobile-tabs a", text: "Shift"
    assert_select ".mobile-tabs a", text: "More"
    assert_select ".mobile-tabs a", text: "Stock", count: 0
    assert_select ".mobile-tabs a", text: "Buying", count: 0
  end

  test "admin still sees every surface card and hub" do
    sign_in_as(users(:one))
    get root_path

    assert_response :success
    assert_select ".home-surface-card-label", text: "Products"
    assert_select ".mobile-tabs a", text: "Stock"
    assert_select ".mobile-tabs a", text: "Buying"
  end
end
