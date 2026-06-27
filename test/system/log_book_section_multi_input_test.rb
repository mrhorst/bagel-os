require "application_system_test_case"

# A "Multi-input (grid)" Log Section needs at least one sub-input, but the
# inputs list starts empty and only grows when the admin clicks "+ Add input".
# So choosing the Multi-input type — or hitting the "must have at least one
# row" validation error — used to leave the form showing an empty Inputs list
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
    assert_text "Inputs must have at least one row"
    assert_selector ".log-book-fields-row", minimum: 1
    assert_equal "Bagels Left", find_field("Section label").value
    assert_equal 0, LogBookSection.where(title: "Bagels Left").count
  end

  test "filling the starter row creates the Multi-input section" do
    visit new_log_book_section_path

    fill_in "Section label", with: "Bagels Left"
    select "Multi-input (grid)", from: "Input type"
    within first(".log-book-fields-row") do
      fill_in "Label", with: "Plain"
    end
    click_on "Create section"

    assert_text "Log section created."
    section = LogBookSection.find_by(title: "Bagels Left")
    assert section, "section should have been created"
    assert_equal "multi", section.section_type
    assert_equal %w[Plain], section.fields.map { |f| f["label"] }
  end

  test "a partially-filled input row blocks the save instead of being silently dropped" do
    visit new_log_book_section_path

    fill_in "Section label", with: "Bagel counts"
    select "Multi-input (grid)", from: "Input type"

    # First input is complete; the second carries a unit but no label — a row
    # the admin clearly meant to keep. It must not vanish under a success toast.
    within first(".log-book-fields-row") do
      find("input[name='log_book_section[fields][][label]']").set("Plain")
    end
    click_on "+ Add input"
    within all(".log-book-fields-row").last do
      find("input[name='log_book_section[fields][][unit_label]']").set("dozens")
    end

    click_on "Create section"

    # The save is rejected with a row-specific message, the section is not
    # created, and the half-filled row (with its unit) is preserved to fix.
    assert_text "Inputs row 2 needs a label"
    assert_equal 0, LogBookSection.where(title: "Bagel counts").count
    assert_selector ".log-book-fields-row", count: 2
    assert_equal "dozens", all("input[name='log_book_section[fields][][unit_label]']").last.value
  end

  test "a fully untouched extra input row is dropped so a valid section still saves" do
    visit new_log_book_section_path

    fill_in "Section label", with: "Bagels Left"
    select "Multi-input (grid)", from: "Input type"
    within first(".log-book-fields-row") do
      find("input[name='log_book_section[fields][][label]']").set("Plain")
    end
    # Add a second row and leave it completely untouched — the seeded/empty
    # starter pattern. It should drop silently, not block the save.
    click_on "+ Add input"

    click_on "Create section"

    assert_text "Log section created."
    section = LogBookSection.find_by(title: "Bagels Left")
    assert section, "section should have been created"
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

  test "the section's last input row cannot be removed into an empty list" do
    visit new_log_book_section_path

    select "Multi-input (grid)", from: "Input type"

    # One starter row, and its remove (×) is hidden — deleting the only input
    # would strand the section with the empty Inputs list (no row to fill) that
    # the seeded starter row exists to prevent.
    assert_selector ".log-book-fields-row", count: 1
    assert_no_selector ".log-book-fields-row-remove", visible: true

    # A second row makes both rows removable.
    click_on "+ Add input"
    assert_selector ".log-book-fields-row", count: 2
    assert_selector ".log-book-fields-row-remove", count: 2, visible: true

    # Removing one drops back to a single row — never zero — and the lone row's
    # × hides again, so the list can't be emptied from the UI.
    first(".log-book-fields-row-remove", visible: true).click
    assert_selector ".log-book-fields-row", count: 1
    assert_no_selector ".log-book-fields-row-remove", visible: true
  end
end
