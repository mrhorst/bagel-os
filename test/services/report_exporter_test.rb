require "test_helper"

class ReportExporterTest < ActiveSupport::TestCase
  setup do
    load Rails.root.join("db/seeds.rb")
    Purchasing::CsvImporter.new.import_file(Rails.root.join("test/fixtures/files/vendor_receipt_sample.csv"))
  end

  test "generates expected report csv files" do
    exporter = Purchasing::ReportExporter.new

    Purchasing::ReportExporter::REPORTS.each do |report|
      csv = exporter.public_send(report)
      assert_includes csv, "\n"
    end

    assert_includes exporter.master_products, "canonical_name"
    assert_includes exporter.price_history, "package_price"
    assert_includes exporter.items_needing_review, "issue_type"
  end
end
