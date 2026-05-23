require "test_helper"

class LogBookResponseTest < ActiveSupport::TestCase
  test "snapshots section label and validates number responses" do
    section = LogBookSection.create!(
      title: "Bagels Left",
      section_type: "number",
      unit_label: "bagels"
    )
    entry = LogBookEntry.create!(operating_date: Date.current)

    response = entry.log_book_responses.create!(
      log_book_section: section,
      section_title_snapshot: section.title,
      section_type_snapshot: section.section_type,
      value_number: 42
    )

    assert_equal "Bagels Left", response.section_title_snapshot
    assert_equal "42.0", response.display_value
  end

  test "blocks no note when the section does not allow it" do
    section = LogBookSection.create!(
      title: "Safe Count",
      section_type: "number",
      allow_no_note: false
    )
    entry = LogBookEntry.create!(operating_date: Date.current)

    response = entry.log_book_responses.build(
      log_book_section: section,
      section_title_snapshot: section.title,
      section_type_snapshot: section.section_type,
      no_note: true
    )

    refute response.valid?
    assert_includes response.errors[:no_note], "is not allowed for this section"
  end
end
