require "test_helper"

class LogBookSectionTest < ActiveSupport::TestCase
  # A failed save must name fields using the words the admin sees on the form,
  # not the raw column names. The Log Section form labels these inputs
  # "Section label", "Input type", "Sort order", "Decimal places", and "Inputs"
  # — so the validation errors must say the same, or the admin is told to fix a
  # field that isn't on screen ("Position is not a number", "Fields must…").
  test "validation errors use the form's labels, not raw column names" do
    section = LogBookSection.new(title: "", section_type: "bogus", position: "", value_decimals: 9)
    section.valid?
    messages = section.errors.full_messages.join(" | ")

    # Speaks the on-screen labels…
    assert_includes messages, "Section label can't be blank"
    assert_includes messages, "Input type is not included in the list"
    assert_includes messages, "Sort order is not a number"
    assert_includes messages, "Decimal places must be in 0..6"

    # …and never leaks the raw attribute names the admin can't find.
    %w[Title Section\ type Position Value\ decimals].each do |raw|
      refute_includes messages, "#{raw} ", "error leaked raw attribute name #{raw.inspect}"
    end
  end

  test "multi-input field errors are named Inputs to match the form heading" do
    no_rows = LogBookSection.new(title: "Counts", section_type: "multi", position: 1, fields: [])
    no_rows.valid?
    assert_includes no_rows.errors.full_messages, "Inputs must have at least one row"
    refute no_rows.errors.full_messages.any? { |m| m.start_with?("Fields") },
      "field error leaked the raw 'Fields' name"

    missing_label = LogBookSection.new(
      title: "Counts", section_type: "multi", position: 1,
      fields: [ { "key" => "a", "label" => "", "type" => "number" } ]
    )
    missing_label.valid?
    assert_includes missing_label.errors.full_messages, "Inputs row 1 needs a label"

    dup_keys = LogBookSection.new(
      title: "Counts", section_type: "multi", position: 1,
      fields: [
        { "key" => "p", "label" => "Plain", "type" => "number" },
        { "key" => "p", "label" => "Plain", "type" => "number" }
      ]
    )
    dup_keys.valid?
    assert_includes dup_keys.errors.full_messages, "Inputs must have unique labels"
  end
end
