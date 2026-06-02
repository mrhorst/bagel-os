require "test_helper"

class DashboardHelperTest < ActionView::TestCase
  def stub_user(name)
    User.new(name: name, email_address: "x@example.com")
  end

  test "greeting picks the part of day from the hour" do
    user = stub_user("Sam Rivera")

    assert_equal "Good morning, Sam",   dashboard_greeting(user, Time.zone.parse("2026-06-02 08:00"))
    assert_equal "Good afternoon, Sam", dashboard_greeting(user, Time.zone.parse("2026-06-02 13:00"))
    assert_equal "Good evening, Sam",   dashboard_greeting(user, Time.zone.parse("2026-06-02 21:00"))
    assert_equal "Good evening, Sam",   dashboard_greeting(user, Time.zone.parse("2026-06-02 03:00"))
  end

  test "greeting omits the name when the user has none" do
    assert_equal "Good morning", dashboard_greeting(stub_user(nil), Time.zone.parse("2026-06-02 08:00"))
    assert_equal "Good morning", dashboard_greeting(nil, Time.zone.parse("2026-06-02 08:00"))
  end
end
