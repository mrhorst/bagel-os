require "test_helper"

class DashboardChartkickTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
    Purchasing::CsvImporter.new.import_file(Rails.root.join("test/fixtures/files/vendor_receipt_tuna_variations.csv"))
  end

  test "dashboard renders chartkick spend charts" do
    get root_path

    assert_response :success
    assert_select "h1", "Operations dashboard"
    assert_select ".dashboard-layout"
    assert_select ".dashboard-block", minimum: 8
    assert_select ".dashboard-priority-strip .dashboard-metric-card", count: 4
    assert_select "a", text: "Review queue"
    assert_select "a", text: "Import CSV"
    assert_select "h2", text: "Work that needs attention"
    assert_select "h2", text: "Price spikes"
    assert_select "h2", text: "Order-guide gaps"
    assert_select "#monthly-spend-chart"
    assert_select "#category-spend-chart"
    assert_select "script", text: /new Chartkick\["LineChart"\]\("monthly-spend-chart"/
    assert_select "script", text: /new Chartkick\["PieChart"\]\("category-spend-chart"/
    assert_select "table.dashboard-table", minimum: 4
  end
end
