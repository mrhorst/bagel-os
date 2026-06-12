require "test_helper"

class AgentCliFollowUpsTest < ActiveSupport::TestCase
  test "creates a follow-up with attribution and urgency" do
    status, payload = run_cli(
      "follow-ups", "create", "--title", "Mixer making noise",
      "--description", "Grinding sound on speed 2",
      "--urgency", "important", "--user", "one@example.com"
    )

    assert_equal 0, status
    follow_up = payload.dig("data", "follow_up")
    assert_equal "open", follow_up["status"]
    assert_equal "important", follow_up["urgency"]
    assert_equal "one@example.com", follow_up.dig("opened_by", "email")
  end

  test "create requires a title" do
    status, payload = run_cli("follow-ups", "create", "--urgency", "urgent")

    assert_equal 1, status
    assert_match(/--title is required/, payload["error"])
  end

  test "rejects an invalid urgency before touching the database" do
    status, payload = run_cli("follow-ups", "create", "--title", "X", "--urgency", "panic")

    assert_equal 1, status
    assert_match(/--urgency must be one of/, payload["error"])
    assert_equal 0, FollowUp.count
  end

  test "updates assignment and clears it" do
    follow_up = open_follow_up

    status, payload = run_cli("follow-ups", "update", follow_up.id.to_s, "--assign", "two@example.com")
    assert_equal 0, status
    assert_equal "two@example.com", payload.dig("data", "follow_up", "assigned_to", "email")

    status, payload = run_cli("follow-ups", "update", follow_up.id.to_s, "--unassign")
    assert_equal 0, status
    assert_nil payload.dig("data", "follow_up", "assigned_to")
  end

  test "resolves and reopens with audit fields" do
    follow_up = open_follow_up

    status, payload = run_cli(
      "follow-ups", "resolve", follow_up.id.to_s,
      "--via", "not_an_issue", "--note", "False alarm", "--user", "one@example.com"
    )

    assert_equal 0, status
    resolved = payload.dig("data", "follow_up")
    assert_equal "resolved", resolved["status"]
    assert_equal "not_an_issue", resolved["resolved_via"]
    assert_equal "False alarm", resolved["resolution_note"]
    assert_equal "one@example.com", resolved.dig("resolved_by", "email")

    status, _ = run_cli("follow-ups", "resolve", follow_up.id.to_s)
    assert_equal 1, status, "resolving twice should fail"

    status, payload = run_cli("follow-ups", "reopen", follow_up.id.to_s)
    assert_equal 0, status
    reopened = payload.dig("data", "follow_up")
    assert_equal "open", reopened["status"]
    assert_nil reopened["resolved_at"]
  end

  test "adds a note with an author" do
    follow_up = open_follow_up

    status, payload = run_cli(
      "follow-ups", "note", follow_up.id.to_s,
      "--body", "Tech visit booked for Friday", "--user", "two@example.com"
    )

    assert_equal 0, status
    notes = payload.dig("data", "follow_up", "notes")
    assert_equal 1, notes.size
    assert_equal "Tech visit booked for Friday", notes.first["body"]
    assert_equal "two@example.com", notes.first.dig("author", "email")
  end

  test "list defaults to open follow-ups ordered by urgency" do
    open_follow_up(title: "Normal thing", urgency: "normal")
    open_follow_up(title: "Urgent thing", urgency: "urgent")
    resolved = open_follow_up(title: "Done thing")
    resolved.resolve!(user: nil)

    _, payload = run_cli("follow-ups", "list")
    titles = payload.dig("data", "follow_ups").map { |f| f["title"] }
    assert_equal [ "Urgent thing", "Normal thing" ], titles

    _, payload = run_cli("follow-ups", "list", "--status", "all")
    assert_equal 3, payload.dig("data", "count")
  end

  private

  def run_cli(*argv)
    out = StringIO.new
    status = AgentCli::Runner.run(argv, out: out)
    [ status, JSON.parse(out.string) ]
  end

  def open_follow_up(title: "Something broke", urgency: "normal")
    FollowUp.create!(title: title, urgency: urgency, status: "open", opened_at: Time.current)
  end
end
