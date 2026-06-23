require "test_helper"

class ReportsIndexTest < ActionDispatch::IntegrationTest
  test "lists each report with a plain-language description of its contents" do
    get reports_path

    assert_response :success

    # The page must describe what each export contains, not just restate the
    # filename. Before this regression guard the "Description" column rendered
    # report.humanize ("Category spend summary"), which is just the name again.
    Purchasing::ReportExporter::REPORTS.each do |report|
      description = Purchasing::ReportExporter.description_for(report)
      assert_not_equal report.humanize, description,
        "#{report} still falls back to its humanized name instead of a real description"
      assert_includes response.body, description,
        "Reports page is missing the description for #{report}"
    end
  end

  test "still surfaces the downloadable filename for each report" do
    get reports_path

    assert_response :success
    Purchasing::ReportExporter::REPORTS.each do |report|
      assert_includes response.body, "#{report}.csv",
        "Reports page no longer shows the #{report}.csv filename"
    end
  end
end
