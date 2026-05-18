require "test_helper"
require "tempfile"

class OrderGuideImporterTest < ActiveSupport::TestCase
  ExtractorStub = Struct.new(:text) do
    def extract(_path)
      text
    end
  end

  setup do
    @supplier = Supplier.create!(name: "Primary Supplier")
    @supplier.products.create!(canonical_name: "Half and Half")
  end

  test "imports guide rows, links confident products, and skips duplicate files" do
    text = <<~TEXT
      Demo Restaurant - Weekly Order Guide
      Dairy & Refrigerated                                                 Par         Pack Qty     Sunday    Thursday     On Hand   Order
                        Half n Half                                         4              quart
      Frozen                                               Par     Pack Qty          Sunday   Thursday   On Hand   Order
                        Fries
    TEXT

    Tempfile.create([ "order-guide", ".pdf" ]) do |file|
      file.write("fake pdf bytes")
      file.close

      importer = Purchasing::OrderGuideImporter.new(extractor: ExtractorStub.new(text))
      first = importer.import_file(file.path, guide_type: "weekly")
      second = importer.import_file(file.path, guide_type: "weekly")

      assert_not first.skipped
      assert second.skipped
      assert_equal 2, first.rows_imported
      assert_equal 1, OrderGuideImport.count
      assert_equal 2, OrderGuideItem.active.count
      assert_equal 2, InventoryItem.active.count
      assert_equal "Half and Half", OrderGuideItem.find_by!(item_name: "Half n Half").linked_product.canonical_name
      assert_equal "Weekly", InventoryItem.find_by!(name: "Half n Half").primary_order_guide.name
      assert OrderGuideItem.find_by!(item_name: "Fries").needs_review?
    end
  end

  test "infers guide type from daily and weekly filenames" do
    text = <<~TEXT
      Dairy & Refrigerated                                                 Par         Pack Qty     Sunday    Thursday     On Hand   Order
                        Half n Half                                         4              quart
    TEXT

    Tempfile.create([ "daily-order-guide", ".pdf" ]) do |daily_file|
      daily_file.write("daily pdf bytes")
      daily_file.close

      daily_result = Purchasing::OrderGuideImporter.new(extractor: ExtractorStub.new(text)).import_file(daily_file.path)
      assert_equal "daily", daily_result.import.guide_type
    end

    Tempfile.create([ "weekly-order-guide", ".pdf" ]) do |weekly_file|
      weekly_file.write("weekly pdf bytes")
      weekly_file.close

      weekly_result = Purchasing::OrderGuideImporter.new(extractor: ExtractorStub.new(text)).import_file(weekly_file.path)
      assert_equal "weekly", weekly_result.import.guide_type
    end
  end

  test "requires guide type when filename does not identify daily or weekly guide" do
    Tempfile.create([ "supplier-list", ".pdf" ]) do |file|
      file.write("unknown guide bytes")
      file.close

      error = assert_raises(ArgumentError) do
        Purchasing::OrderGuideImporter.new(extractor: ExtractorStub.new("")).import_file(file.path)
      end

      assert_match(/Could not infer guide type/, error.message)
    end
  end
end
