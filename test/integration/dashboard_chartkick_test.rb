require "test_helper"

class DashboardChartkickTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb")
    Purchasing::CsvImporter.new.import_file(Rails.root.join("test/fixtures/files/vendor_receipt_tuna_variations.csv"))
  end

  test "dashboard renders chartkick spend charts" do
    get root_path

    assert_response :success
    assert_select "#monthly-spend-chart"
    assert_select "#category-spend-chart"
    assert_select "script", text: /new Chartkick\["LineChart"\]\("monthly-spend-chart"/
    assert_select "script", text: /new Chartkick\["PieChart"\]\("category-spend-chart"/
    assert_select "table", minimum: 2
  end
end
