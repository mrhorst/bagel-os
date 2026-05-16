require "test_helper"

class OrderGuideTextParserTest < ActiveSupport::TestCase
  test "parses guide sections, subcategories, and rows without inventing units" do
    text = <<~TEXT
      Demo Restaurant - Daily Order Guide
      Bread & Bakery                   Par       Pack Qty    On Hand       Order
                 Bagels
                 Plain                       6   unit
                 Sliced Bread
                 Rye                         3
      Dairy & Refrigerated             Par       Pack Qty    On Hand       Order
                 Half-and-half                   quart
    TEXT

    rows = Purchasing::OrderGuideTextParser.new.parse(text, guide_type: "daily")

    assert_equal 3, rows.size
    assert_equal "Bread & Bakery", rows.first[:section_name]
    assert_equal "Bagels", rows.first[:subcategory]
    assert_equal "Plain", rows.first[:item_name]
    assert_equal "6", rows.first[:par_text]
    assert_equal "unit", rows.first[:pack_quantity]
    assert_equal "Sliced Bread", rows.second[:subcategory]
    assert_equal "Rye", rows.second[:item_name]
    assert_equal "quart", rows.third[:par_text]
    assert_nil rows.third[:pack_quantity]
  end
end
