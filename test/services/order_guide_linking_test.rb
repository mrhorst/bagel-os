require "test_helper"

class OrderGuideLinkingTest < ActiveSupport::TestCase
  StaticMatcher = Struct.new(:matches) do
    def match(raw_name, context: {})
      value = matches.fetch(raw_name)
      value.respond_to?(:call) ? value.call(context) : value
    end
  end

  setup do
    @supplier = Supplier.create!(name: "Primary Supplier")
    @half_and_half = @supplier.products.create!(canonical_name: "Half and Half")
    @oat_milk = @supplier.products.create!(canonical_name: "Oat Milk")
    @suggested = @supplier.products.create!(canonical_name: "American Cheese Yellow")
    @import = OrderGuideImport.create!(
      source_filename: "guide.pdf",
      guide_type: "weekly",
      file_checksum: SecureRandom.hex(12),
      imported_at: Time.current,
      status: "imported"
    )
  end

  test "links confident guide rows and records match metadata" do
    result = linker_for(
      "Half n Half" => match(product: @half_and_half, confidence: "0.90", basis: "plain-language order guide rule")
    ).link_row!(import: @import, row: row(item_name: "Half n Half"))

    guide_item = result.guide_item
    inventory_item = result.inventory_item

    assert result.linked?
    assert_equal @half_and_half, guide_item.linked_product
    assert_equal @half_and_half, inventory_item.product
    assert_not guide_item.needs_review?
    assert_not inventory_item.needs_review?
    assert_equal BigDecimal("0.9"), guide_item.match_confidence
    assert_equal "plain-language order guide rule", guide_item.raw_data["match_basis"]
    assert_equal "Dairy & Refrigerated", inventory_item.inventory_section.name
  end

  test "does not link below the confidence threshold" do
    result = linker_for(
      "Oatmilk" => match(product: @oat_milk, confidence: "0.89", basis: "almost but not enough")
    ).link_row!(import: @import, row: row(item_name: "Oatmilk"))

    assert_not result.linked?
    assert_nil result.guide_item.linked_product
    assert result.guide_item.needs_review?
    assert result.inventory_item.needs_review?
    assert_equal BigDecimal("0.89"), result.guide_item.match_confidence
  end

  test "covered product ids uses the same confidence policy" do
    linker = linker_for(
      "Half n Half" => match(product: @half_and_half, confidence: "0.90", basis: "plain-language order guide rule"),
      "Oatmilk" => match(product: @oat_milk, confidence: "0.89", basis: "almost but not enough")
    )

    linker.link_row!(import: @import, row: row(item_name: "Half n Half", position: 1))
    linker.link_row!(import: @import, row: row(item_name: "Oatmilk", position: 2))

    covered_ids = linker.covered_product_ids
    assert_includes covered_ids, @half_and_half.id
    assert_not_includes covered_ids, @oat_milk.id
  end

  test "clears stale links and stores suggestions for ambiguous existing guide rows" do
    old_product = @supplier.products.create!(canonical_name: "American Cheese")
    inventory_item = InventoryItem.create!(name: "American", key: "american", product: old_product, needs_review: false)
    guide_item = @import.order_guide_items.create!(
      inventory_item: inventory_item,
      guide_type: "weekly",
      section_name: "Dairy & Refrigerated",
      item_name: "American",
      raw_line: "American",
      needs_review: false,
      match_confidence: BigDecimal("0.93")
    )

    linker_for(
      "American" => match(product: nil, suggested_product: @suggested, confidence: "0.40", basis: "low-confidence token similarity")
    ).refresh_item!(guide_item)

    assert_nil inventory_item.reload.product
    assert inventory_item.needs_review?
    assert_nil guide_item.reload.linked_product
    assert guide_item.needs_review?
    assert_equal @suggested.id, guide_item.raw_data["suggested_product_id"]
    assert_equal "American Cheese Yellow", guide_item.raw_data["suggested_product_name"]
  end

  test "clears stale suggestions after a confident refresh" do
    inventory_item = InventoryItem.create!(name: "Half n Half", key: "half-n-half", needs_review: true)
    guide_item = @import.order_guide_items.create!(
      inventory_item: inventory_item,
      guide_type: "weekly",
      section_name: "Dairy & Refrigerated",
      item_name: "Half n Half",
      raw_line: "Half n Half",
      needs_review: true,
      raw_data: {
        "suggested_product_id" => @suggested.id,
        "suggested_product_name" => @suggested.canonical_name
      }
    )

    linker_for(
      "Half n Half" => match(product: @half_and_half, confidence: "0.90", basis: "plain-language order guide rule")
    ).refresh_item!(guide_item)

    assert_equal @half_and_half, guide_item.reload.linked_product
    assert_nil guide_item.raw_data["suggested_product_id"]
    assert_nil guide_item.raw_data["suggested_product_name"]
  end

  test "splits shared inventory items when rows resolve to different products" do
    patties = @supplier.products.create!(canonical_name: "Sausage Patties")
    links = @supplier.products.create!(canonical_name: "Sausage Links")
    old_sausage = @supplier.products.create!(canonical_name: "Sausage")
    shared_item = InventoryItem.create!(name: "Sausage patties", key: "sausage-patties", product: old_sausage, needs_review: false)
    patties_row = @import.order_guide_items.create!(
      inventory_item: shared_item,
      guide_type: "weekly",
      section_name: "Frozen",
      item_name: "Sausage patties",
      raw_line: "Sausage patties"
    )
    links_row = @import.order_guide_items.create!(
      inventory_item: shared_item,
      guide_type: "weekly",
      section_name: "Frozen",
      item_name: "Sausage Links",
      raw_line: "Sausage Links"
    )

    stats = linker_for(
      "Sausage patties" => match(product: patties, confidence: "0.93", basis: "plain-language order guide rule"),
      "Sausage Links" => match(product: links, confidence: "0.93", basis: "plain-language order guide rule")
    ).refresh_all!

    assert_equal({ reviewed: 2, linked: 2 }, stats)
    assert_equal patties, patties_row.reload.linked_product
    assert_equal links, links_row.reload.linked_product
    assert_not_equal patties_row.inventory_item_id, links_row.inventory_item_id
  end

  private

  def linker_for(matches)
    Purchasing::OrderGuideLinking.new(matcher: StaticMatcher.new(matches))
  end

  def match(product:, confidence:, basis:, suggested_product: nil)
    Purchasing::ProductNameMatcher::Match.new(
      product: product,
      suggested_product: suggested_product,
      confidence: BigDecimal(confidence),
      basis: basis
    )
  end

  def row(item_name:, section_name: "Dairy & Refrigerated", subcategory: nil, position: 1)
    {
      guide_type: "weekly",
      section_name: section_name,
      subcategory: subcategory,
      item_name: item_name,
      guide_sku: nil,
      par_text: "4",
      pack_quantity: "quart",
      sunday_target: nil,
      thursday_target: nil,
      raw_line: item_name,
      position: position
    }
  end
end
