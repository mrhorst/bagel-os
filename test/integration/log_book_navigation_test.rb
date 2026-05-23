require "test_helper"

class LogBookNavigationTest < ActionDispatch::IntegrationTest
  test "home tab is selected without also selecting tasks" do
    get root_path

    assert_response :success
    assert_select ".mobile-tab.active", text: "Home"
    assert_select ".mobile-tab.active", text: "Tasks", count: 0
  end

  test "admin can open the log book" do
    get log_book_path

    assert_response :success
    assert_select ".log-book-header .block-eyebrow", count: 0
    assert_select ".mobile-tab", text: "Shift"
    assert_select ".mobile-tab", text: "Log Book", count: 0
    assert_select ".log-book-date-nav"
    assert_select ".module-overflow [data-popover-target='trigger']"
    assert_select ".popover-panel-menu a", text: "Settings"
    assert_select ".popover-panel-menu a", text: "History"
  end

  test "employee needs log book permission" do
    employee = users(:two)
    sign_in_as(employee)

    get log_book_path
    assert_redirected_to root_path

    employee.grant_module("log_book")
    get log_book_path
    assert_response :success
  end
end
