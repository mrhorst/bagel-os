require "test_helper"

class OrderGuideTest < ActiveSupport::TestCase
  test "key_for slugifies names and expands ampersands" do
    assert_equal "produce-and-herbs", OrderGuide.key_for("Produce & Herbs")
    assert_equal "dry-goods", OrderGuide.key_for("  Dry   Goods  ")
  end

  test "assigns a key from the name on save" do
    assert_equal "dairy", OrderGuide.create!(name: "Dairy").key
  end

  test "name is required and key is unique" do
    OrderGuide.create!(name: "Paper")
    duplicate = OrderGuide.new(name: "Paper")

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
    assert_not OrderGuide.new.valid?
  end

  test "named! is idempotent and reactivates an archived guide" do
    first = OrderGuide.named!("Frozen")
    again = OrderGuide.named!("Frozen")
    assert_equal first.id, again.id

    first.update!(active: false)
    reactivated = OrderGuide.named!("Frozen")
    assert reactivated.active?
  end

  test "section_named! finds or creates active sections and defaults the name" do
    guide = OrderGuide.create!(name: "Beverages")

    first = guide.section_named!("Sodas")
    again = guide.section_named!("Sodas")
    assert_equal first.id, again.id
    assert first.active?

    assert_equal "Unsectioned", guide.section_named!(nil).name
  end

  test "archive! deactivates the guide and its active memberships" do
    guide = OrderGuide.create!(name: "Cleaning")

    guide.archive!

    assert guide.archived?
    assert_not guide.active?
  end
end
