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

  test "each report download uses the PWA-safe download pattern" do
    get reports_path

    assert_response :success
    # A same-window nav to a Content-Disposition: attachment link strands an
    # installed PWA on a chrome-less page. Every download must route through
    # download_controller (with a target=_blank no-JS fallback), like the photo
    # downloads already do.
    Purchasing::ReportExporter::REPORTS.each do |report|
      assert_select(
        %(a[href="#{report_path(report)}"][data-controller~="download"][data-action~="download#save"][target="_blank"][rel="noopener"][data-download-filename-value="#{report}.csv"]),
        { count: 1 },
        "#{report} download is missing the PWA-safe download wiring"
      )
    end
  end
end
