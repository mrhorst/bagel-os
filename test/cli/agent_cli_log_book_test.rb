require "test_helper"

class AgentCliLogBookTest < ActiveSupport::TestCase
  setup do
    @notes = LogBookSection.create!(title: "Shift notes", section_type: "long_text")
    @temp = LogBookSection.create!(title: "Fridge temp", section_type: "number", unit_label: "F")
  end

  test "set creates today's entry and a snapshotted response" do
    status, payload = run_cli(
      "log-book", "set", "--section", @notes.id.to_s,
      "--text", "Busy lunch", "--user", "one@example.com"
    )

    assert_equal 0, status
    response = payload.dig("data", "response")
    assert_equal "Busy lunch", response["value_text"]
    assert_equal "Shift notes", response["section_title"]
    assert_equal "one@example.com", response.dig("last_submitted_by", "email")

    entry = LogBookEntry.find_by!(operating_date: Time.zone.today)
    assert_equal users(:one), entry.submitted_by
  end

  test "set finds a section by exact title" do
    status, payload = run_cli("log-book", "set", "--section", "fridge temp", "--number", "38")

    assert_equal 0, status
    assert_equal "38.0", payload.dig("data", "response", "value_number")
  end

  test "flagging preserves the existing value and opens a follow-up" do
    run_cli("log-book", "set", "--section", @notes.id.to_s, "--text", "Oven acting up")

    status, payload = run_cli("log-book", "set", "--section", @notes.id.to_s, "--flag", "--urgency", "urgent")

    assert_equal 0, status
    response = payload.dig("data", "response")
    assert_equal "Oven acting up", response["value_text"], "flagging should not wipe the value"
    assert response["flagged_for_follow_up"]

    follow_up = payload.dig("data", "follow_up")
    assert_equal "open", follow_up["status"]
    assert_equal "urgent", follow_up["urgency"]
    assert_equal 1, FollowUp.where(origin_type: "LogBookResponse").count
  end

  test "unflagging resolves the open follow-up" do
    run_cli("log-book", "set", "--section", @notes.id.to_s, "--text", "Leak", "--flag")

    status, payload = run_cli("log-book", "set", "--section", @notes.id.to_s, "--unflag")

    assert_equal 0, status
    assert_equal "resolved", payload.dig("data", "follow_up", "status")
  end

  test "rejects a value flag that does not match the section type" do
    status, payload = run_cli("log-book", "set", "--section", @temp.id.to_s, "--text", "warm")

    assert_equal 1, status
    assert_match(/--text cannot be used on a number section/, payload["error"])
  end

  test "no-note clears values and grid validation flows through" do
    run_cli("log-book", "set", "--section", @notes.id.to_s, "--text", "Something")

    status, payload = run_cli("log-book", "set", "--section", @notes.id.to_s, "--no-note")

    assert_equal 0, status
    response = payload.dig("data", "response")
    assert response["no_note"]
    assert_nil response["value_text"]
  end

  test "set writes grid values on multi sections and merges across calls" do
    multi = LogBookSection.create!(
      title: "Closing checks", section_type: "multi",
      fields: [
        { "label" => "Ovens off", "type" => "yes_no", "key" => "ovens_off" },
        { "label" => "Bagels left", "type" => "number", "key" => "bagels_left" }
      ]
    )

    run_cli("log-book", "set", "--section", multi.id.to_s, "--grid", "ovens_off=yes")
    status, payload = run_cli("log-book", "set", "--section", multi.id.to_s, "--grid", "bagels_left=12")

    assert_equal 0, status
    assert_equal({ "ovens_off" => "yes", "bagels_left" => "12" }, payload.dig("data", "response", "value_grid"))
  end

  test "show returns responses for a date and an empty shell when no entry exists" do
    run_cli("log-book", "set", "--section", @notes.id.to_s, "--text", "Hello")

    _, payload = run_cli("log-book", "show")
    assert payload.dig("data", "exists")
    assert_equal 1, payload.dig("data", "responses").size

    _, payload = run_cli("log-book", "show", "--date", (Time.zone.today - 1).iso8601)
    assert_not payload.dig("data", "exists")
    assert_empty payload.dig("data", "responses")
  end

  test "sections lists active sections" do
    _, payload = run_cli("log-book", "sections")

    titles = payload.dig("data", "sections").map { |s| s["title"] }
    assert_includes titles, "Shift notes"
    assert_includes titles, "Fridge temp"
  end

  private

  def run_cli(*argv)
    out = StringIO.new
    status = AgentCli::Runner.run(argv, out: out)
    [ status, JSON.parse(out.string) ]
  end
end
