require "test_helper"

class OrderGuideMatchRefresherTest < ActiveSupport::TestCase
  setup do
    @supplier = Supplier.create!(name: "Primary Supplier")
    @supplier.products.create!(canonical_name: "American Cheese Yellow")
    @supplier.products.create!(canonical_name: "American Cheese White")
    @old_product = @supplier.products.create!(canonical_name: "American Cheese")
    @inventory_item = InventoryItem.create!(name: "American", key: "american", product: @old_product, needs_review: false)
    @import = OrderGuideImport.create!(
      source_filename: "guide.pdf",
      guide_type: "weekly",
      file_checksum: "abc123",
      imported_at: Time.current,
      status: "imported"
    )
    @guide_item = @import.order_guide_items.create!(
      inventory_item: @inventory_item,
      guide_type: "weekly",
      section_name: "Dairy & Refrigerated",
      item_name: "American",
      raw_line: "American",
      needs_review: false,
      match_confidence: 0.93
    )
  end

  test "clears stale guide links when a formerly linked row becomes ambiguous" do
    Purchasing::OrderGuideMatchRefresher.new.refresh!

    assert_nil @inventory_item.reload.product
    assert @inventory_item.needs_review?
    assert @guide_item.reload.needs_review?
    assert_nil @guide_item.linked_product
  end
end

class OrderGuideMatchRefresherSharedItemTest < ActiveSupport::TestCase
  setup do
    supplier = Supplier.create!(name: "Primary Supplier")
    @patties = supplier.products.create!(canonical_name: "Sausage Patties")
    @links = supplier.products.create!(canonical_name: "Sausage Links")
    old_sausage = supplier.products.create!(canonical_name: "Sausage")
    @shared_item = InventoryItem.create!(name: "Sausage patties", key: "sausage-patties", product: old_sausage, needs_review: false)
    import = OrderGuideImport.create!(
      source_filename: "guide.pdf",
      guide_type: "weekly",
      file_checksum: "def456",
      imported_at: Time.current,
      status: "imported"
    )
    @patties_row = import.order_guide_items.create!(
      inventory_item: @shared_item,
      guide_type: "weekly",
      section_name: "Frozen",
      item_name: "Sausage patties",
      raw_line: "Sausage patties"
    )
    @links_row = import.order_guide_items.create!(
      inventory_item: @shared_item,
      guide_type: "weekly",
      section_name: "Frozen",
      item_name: "Sausage Links",
      raw_line: "Sausage Links"
    )
  end

  test "splits guide rows that used to share one broad inventory item" do
    Purchasing::OrderGuideMatchRefresher.new.refresh!

    assert_equal @patties, @patties_row.reload.linked_product
    assert_equal @links, @links_row.reload.linked_product
    assert_not_equal @patties_row.inventory_item_id, @links_row.inventory_item_id
  end
end
