require "test_helper"

# Guards the qa:flows "order-guides" journey coverage. The flow is named
# "Order guides → guide → back", but the "CSV example" download link
# (/order_guides/csv_example) also matches a[href*='/order_guides/'] and renders
# FIRST in the page heading. With a bare selector the harness drilled into that
# send_data download (a non-navigating fallback-visit) and never reached a guide,
# so its back-walk + referrer probe silently tested the INDEX chevron instead of
# the guide show page's "Back to Order Guides" arrow this flow exists to exercise.
#
# This test reads the real drill selector straight from lib/tasks/qa.rake and
# applies it to the rendered index, so reverting the csv_example exclusion
# re-introduces the bug and fails here.
class OrderGuidesFlowCoverageTest < ActionDispatch::IntegrationTest
  test "the order-guides qa drill selector reaches a guide, not the CSV example download" do
    guide = OrderGuide.create!(name: "Daily")

    get order_guides_path
    assert_response :success

    selector = order_guides_drill_selector
    link = Nokogiri::HTML(response.body).at_css(selector)

    assert link, "qa:flows order-guides drill selector #{selector.inspect} matched no link on the index"
    assert_equal order_guide_path(guide), link["href"],
      "drill should reach the guide show page, got #{link["href"].inspect}"
    refute_equal csv_example_order_guides_path, link["href"],
      "drill must not land on the CSV example download"
  end

  private

  # Pull the first CSS selector from the order-guides flow's `drill:` array in
  # the qa harness, so this test exercises whatever the harness actually uses.
  def order_guides_drill_selector
    rake = File.read(Rails.root.join("lib/tasks/qa.rake"))
    selector = rake[/slug:\s*"order-guides".*?drill:\s*\[\s*"([^"]+)"/m, 1]
    assert selector, "could not locate the order-guides drill selector in lib/tasks/qa.rake"
    selector
  end
end
