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

  test "rejects a duplicate slug with a name-anchored message (no leaked Slug field)" do
    # An explicitly typed slug that collides still has to be rejected, but the
    # message must read in name terms and name the tag that actually owns the
    # slug — never a bare "Slug has already been taken" the admin can't act on.
    dup = Tag.new(name: "Food again", slug: "food")
    assert_not dup.valid?
    assert_includes dup.errors[:base], %(A tag named "Food" already exists. Pick a different name or slug.)
    assert_empty dup.errors[:slug]
    assert_not_includes dup.errors.full_messages.to_sentence, "Slug"
  end

  test "a duplicate name with a blank (derived) slug is rejected in name terms" do
    # The headline case: the admin follows the form's "Leave blank to derive it
    # from the name" hint, re-types an existing name, and must NOT get an error
    # about the Slug field they deliberately left empty.
    dup = Tag.new(name: "Food")
    assert_not dup.valid?
    assert_equal "food", dup.slug
    assert_includes dup.errors[:base], %(A tag named "Food" already exists. Pick a different name or slug.)
    assert_empty dup.errors[:slug]
  end

  test "editing a tag's slug onto another tag's slug is rejected in name terms" do
    promo = tags(:inactive_promo)
    promo.slug = "food" # already owned by the Food tag
    assert_not promo.valid?
    assert_includes promo.errors[:base], %(A tag named "Food" already exists. Pick a different name or slug.)
    assert_empty promo.errors[:slug]
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
