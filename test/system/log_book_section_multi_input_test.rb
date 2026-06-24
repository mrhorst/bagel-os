require "application_system_test_case"

# A "Multi-input (grid)" Log Section needs at least one sub-input, but the
# inputs list starts empty and only grows when the admin clicks "+ Add input".
# So choosing the Multi-input type — or hitting the "must have at least one
# input" validation error — used to leave the form showing an empty Inputs list
# with no row to fill: the error demanded an input the form never surfaced. The
# form now seeds one blank starter row whenever a section has no inputs yet.
class LogBookSectionMultiInputTest < ApplicationSystemTestCase
  setup { sign_in_as users(:one) }

  test "choosing Multi-input shows a starter input row to fill" do
    visit new_log_book_section_path

    select "Multi-input (grid)", from: "Input type"

    # The inputs manager is now visible with exactly one blank starter row —
    # not an empty list the user has to discover "+ Add input" to populate.
    assert_selector ".log-book-fields-manager:not([hidden])"
    assert_selector ".log-book-fields-row", count: 1
  end

  test "submitting a Multi-input section with no inputs re-renders a row to fill" do
    visit new_log_book_section_path

    fill_in "Section label", with: "Bagels Left"
    select "Multi-input (grid)", from: "Input type"
    # Leave the starter row blank and submit — the model rejects it.
    click_on "Create section"

    # The error must come with a row the user can act on, not an empty list.
    assert_text "must have at least one input"
    assert_selector ".log-book-fields-row", minimum: 1
    assert_equal "Bagels Left", find_field("Section label").value
    assert_equal 0, LogBookSection.where(title: "Bagels Left").count
  end

  test "filling the starter row creates the Multi-input section" do
    visit new_log_book_section_path

    fill_in "Section label", with: "Bagels Left"
    select "Multi-input (grid)", from: "Input type"
    fill_in "log_book_section[fields][][label]", with: "Plain"
    click_on "Create section"

    assert_text "Log section created."
    section = LogBookSection.find_by(title: "Bagels Left")
    assert section, "section should have been created"
    assert_equal "multi", section.section_type
    assert_equal %w[Plain], section.fields.map { |f| f["label"] }
  end

  test "editing an existing Multi-input section shows its real rows, no extra starter" do
    section = LogBookSection.create!(
      title: "Closing counts", section_type: "multi", position: 1,
      fields: [
        { "key" => "plain", "label" => "Plain", "type" => "number", "unit_label" => "", "value_decimals" => 0 },
        { "key" => "sesame", "label" => "Sesame", "type" => "number", "unit_label" => "", "value_decimals" => 0 }
      ]
    )

    visit edit_log_book_section_path(section)

    # Two saved inputs render two rows — the empty-list starter must not add a third.
    assert_selector ".log-book-fields-row", count: 2
  end
end
