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
    assert_select ".home-hero h1", text: /Good (morning|afternoon|evening)/
    assert_select ".home-hero p", text: /Today/
    assert_select ".home-ai-recommendation", count: 0
    assert_select ".home-surface-grid"
    assert_select ".home-surface-card .home-surface-card-label", text: "Tasks"
    assert_select ".home-surface-card .home-surface-card-label", text: "Log Book"
    assert_select ".home-surface-card .home-surface-card-label", text: "Review queue"
  end
end
