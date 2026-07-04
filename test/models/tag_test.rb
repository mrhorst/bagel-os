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

  test "a blank name reports only the name error, not the derived-slug field" do
    # The admin submits the new-tag form empty (a whitespace-only name slips past
    # the field's HTML5 `required`). The single mistake is the missing name, so
    # the banner must say exactly that — not pile on "Slug can't be blank" /
    # "Slug must be lowercase…" for a field they were told to leave blank.
    tag = Tag.new(name: "   ")
    assert_not tag.valid?
    assert tag.errors[:name].any?
    assert_empty tag.errors[:slug]
    assert_not_includes tag.errors.full_messages.to_sentence, "Slug"
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

  test "a name with no usable characters is rejected in name terms, not as a Slug field error" do
    # A name that parameterizes to nothing — symbols ("###"), an emoji ("🌮"), or
    # a non-latin script ("料理") — leaves the derived slug blank. The admin typed
    # a name and left the slug blank exactly as instructed, so the error must name
    # what they control (the name), never a "Slug can't be blank" / "Slug must be
    # lowercase…" for a field they never touched. Mirrors the duplicate-slug case.
    [ "###", "🌮", "料理" ].each do |unusable|
      tag = Tag.new(name: unusable)
      assert_not tag.valid?, "expected #{unusable.inspect} to be invalid"
      assert_equal "", tag.slug
      assert_includes tag.errors[:base],
        %("#{unusable}" can't be turned into a tag — its name needs letters or numbers. Edit the name, or type a slug.)
      assert_empty tag.errors[:slug], "expected no leaked Slug field error for #{unusable.inspect}"
      assert_not_includes tag.errors.full_messages.to_sentence, "Slug"
    end
  end

  test "a name with underscores derives a valid slug, not a leaked Slug-format error" do
    # The gap the blank/emoji cases above miss: a name whose derived slug is
    # NON-blank but invalid. parameterize preserves underscores, so a plausible
    # name like "Gluten_Free" derived to "gluten_free" — which the format forbids
    # — and the admin who left the slug blank (as the form instructs) was scolded
    # "Slug must be lowercase words separated by dashes" for a field they never
    # touched. Deriving must fold underscores into dashes so the slug is valid and
    # no Slug-field error leaks.
    [ [ "Gluten_Free", "gluten-free" ], [ "Front_of_House", "front-of-house" ], [ "a__b", "a-b" ] ].each do |name, expected_slug|
      tag = Tag.new(name: name)
      assert tag.valid?, "expected #{name.inspect} to be valid, got: #{tag.errors.full_messages.to_sentence}"
      assert_equal expected_slug, tag.slug
      assert_empty tag.errors[:slug], "expected no leaked Slug field error for #{name.inspect}"
      assert_not_includes tag.errors.full_messages.to_sentence, "Slug"
    end
  end

  test "a typed slug with an underscore is still scolded (format check preserved for typed input)" do
    # The flip side: when the admin actually TYPES a slug, the format validation
    # must still catch a malformed one — the fix only spares the derived case, it
    # doesn't silently rewrite what someone deliberately entered.
    tag = Tag.new(name: "Drinks", slug: "cold_brew")
    assert_not tag.valid?
    assert_includes tag.errors[:slug], "must be lowercase words separated by dashes"
  end

  test "active scope excludes inactive tags" do
    assert_includes Tag.active, tags(:food)
    assert_not_includes Tag.active, tags(:inactive_promo)
  end
end
