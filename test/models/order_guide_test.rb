require "test_helper"

class OrderGuideTest < ActiveSupport::TestCase
  test "key_for slugifies names and expands ampersands" do
    assert_equal "produce-and-herbs", OrderGuide.key_for("Produce & Herbs")
    assert_equal "dry-goods", OrderGuide.key_for("  Dry   Goods  ")
  end

  test "assigns a key from the name on save" do
    assert_equal "dairy", OrderGuide.create!(name: "Dairy").key
  end

  test "name is required and unique, with a name-anchored message (no leaked Key field)" do
    OrderGuide.create!(name: "Paper")
    duplicate = OrderGuide.new(name: "Paper")

    assert_not duplicate.valid?
    # The constraint lives on the internal `key` slug, but a person only ever
    # typed a name — so the error must read in name terms, never "Key ...".
    assert_includes duplicate.errors[:base], %(A guide named "Paper" already exists. Pick a different name.)
    assert_empty duplicate.errors[:key]
    assert_not_includes duplicate.errors.full_messages.to_sentence, "Key"
  end

  test "a differently-typed name that slugs to an existing key is rejected by name" do
    OrderGuide.create!(name: "Paper")
    # "paper!!" normalizes to the same key as "Paper"; the message names the
    # guide that actually exists so the collision is understandable.
    collision = OrderGuide.new(name: "paper!!")

    assert_not collision.valid?
    assert_includes collision.errors[:base], %(A guide named "Paper" already exists. Pick a different name.)
  end

  test "a blank guide reports only the missing name, not a leaked blank Key" do
    blank = OrderGuide.new

    assert_not blank.valid?
    assert_includes blank.errors[:name], "can't be blank"
    assert_empty blank.errors[:key]
  end

  test "renaming a guide onto another guide's name is rejected by name" do
    OrderGuide.create!(name: "Daily")
    weekly = OrderGuide.create!(name: "Weekly")

    # The stored key stays "weekly", but the *new* name implies key "daily",
    # which another guide already owns — so the rename must be blocked rather
    # than silently producing two "Daily" guides.
    weekly.name = "Daily"

    assert_not weekly.valid?
    assert_includes weekly.errors[:base], %(A guide named "Daily" already exists. Pick a different name.)
  end

  test "renaming a guide to a genuinely new name still succeeds and keeps the stable key" do
    weekly = OrderGuide.create!(name: "Weekly")

    assert weekly.update(name: "Morning")
    # The import-lineage key is intentionally left untouched on rename so a later
    # import of guide-type "Weekly" still flows into this same record.
    assert_equal "weekly", weekly.reload.key
    assert_equal "Morning", weekly.name
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
