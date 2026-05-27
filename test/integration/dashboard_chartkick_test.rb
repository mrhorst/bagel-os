require "test_helper"

# The dashboard was replaced with a surface-grid hero; the old chartkick
# spend tables and price-spike tables no longer live here. This test now
# just covers the surface grid and the headline.
class DashboardChartkickTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
  end

  test "dashboard renders the surface grid" do
    get root_path

    assert_response :success
    assert_select "meta[name='viewport'][content='width=device-width,initial-scale=1,minimum-scale=1,maximum-scale=1,user-scalable=no,viewport-fit=cover']", visible: false
    assert_select "h1", text: /Today/
    assert_select ".home-surface-grid"
    assert_select ".home-surface-card .home-surface-card-label", text: "Tasks"
    assert_select ".home-surface-card .home-surface-card-label", text: "Log Book"
    assert_select ".home-surface-card .home-surface-card-label", text: "Review queue"
  end
end
