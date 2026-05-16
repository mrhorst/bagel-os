require "test_helper"

class CasePackFactImporterTest < ActiveSupport::TestCase
  test "imports approved case pack facts from private csv shape" do
    supplier = Supplier.create!(name: "Primary Supplier")
    supplier.products.create!(canonical_name: "American Cheese Yellow")
    file = Tempfile.new([ "case-pack-facts", ".csv" ])
    file.write(<<~CSV)
      supplier_name,product_name,raw_sku,raw_name,units_per_case,inner_unit_label,inner_package_size,inner_unit_of_measure,standard_unit,source,approved,confidence_score,notes
      Primary Supplier,American Cheese Yellow,CHEESE-CASE,CHS AMER YLW 5LB,4,pack,5,lb,lb,manual,true,1,Verified from case label
    CSV
    file.close

    stats = Purchasing::CasePackFactImporter.new.import_file(file.path)

    fact = SupplierProductPack.find_by!(raw_sku: "CHEESE-CASE")
    assert_equal({ rows_processed: 1, facts_upserted: 1 }, stats)
    assert_equal supplier, fact.supplier
    assert_equal "American Cheese Yellow", fact.product.canonical_name
    assert_equal BigDecimal("4"), fact.units_per_case
    assert_equal "pack", fact.inner_unit_label
    assert_equal BigDecimal("5"), fact.inner_package_size
    assert_equal "lb", fact.standard_unit
    assert fact.approved?
  ensure
    file&.unlink
  end
end
