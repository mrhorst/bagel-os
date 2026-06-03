require "test_helper"

# The dashboard was replaced with a surface-grid hero; the old chartkick
# spend tables and price-spike tables no longer live here. This test now
# just covers the surface grid and the headline.
class DashboardChartkickTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
  end

  test "dashboard renders the surface grid" do
    TaskBriefing.create!(
      scope_type: "tasks_dashboard",
      scope_key: "today",
      generated_at: Time.current,
      input_digest: "demo",
      headline: "Opening task is overdue",
      next_action: "Check sanitizer buckets now.",
      priority_items: [],
      source_task_occurrence_ids: []
    )

    get root_path

    assert_response :success
    assert_select ".home-hero h1", text: /Good (morning|afternoon|evening)/
    assert_select ".home-hero p", text: /Today/
    assert_select ".home-ai-recommendation-tag", text: "AI recommendation"
    assert_select ".home-ai-recommendation h2", text: "Opening task is overdue"
    assert_select ".home-ai-recommendation p", text: "Check sanitizer buckets now."
    assert_select ".home-surface-grid"
    assert_select ".home-surface-card .home-surface-card-label", text: "Tasks"
    assert_select ".home-surface-card .home-surface-card-label", text: "Log Book"
    assert_select ".home-surface-card .home-surface-card-label", text: "Review queue"
  end
end
