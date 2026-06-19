require "test_helper"

class TagTest < ActiveSupport::TestCase
  test "derives a slug from the name when blank" do
    tag = Tag.create!(name: "Plated Food")
    assert_equal "plated-food", tag.slug
  end

  test "keeps an explicit slug" do
    tag = Tag.create!(name: "Food", slug: "grub")
    assert_equal "grub", tag.slug
  end

  test "requires a name" do
    tag = Tag.new(name: "")
    assert_not tag.valid?
    assert tag.errors[:name].any?
  end

  test "rejects a duplicate slug" do
    dup = Tag.new(name: "Food again", slug: "food")
    assert_not dup.valid?
    assert tag_includes_slug_error?(dup)
  end

  test "sanitizes a messy slug into the canonical form" do
    tag = Tag.create!(name: "Bad", slug: "Not A Slug")
    assert_equal "not-a-slug", tag.slug
  end

  test "rejects a slug that sanitizes to nothing" do
    tag = Tag.new(name: "###")
    assert_not tag.valid?
    assert tag_includes_slug_error?(tag)
  end

  test "active scope excludes inactive tags" do
    assert_includes Tag.active, tags(:food)
    assert_not_includes Tag.active, tags(:inactive_promo)
  end

  private

  def tag_includes_slug_error?(tag)
    tag.errors[:slug].any?
  end
end
