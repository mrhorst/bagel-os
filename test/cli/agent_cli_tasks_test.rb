require "test_helper"

class AgentCliTasksTest < ActiveSupport::TestCase
  setup do
    @list = TaskList.create!(name: "Opening")
  end

  test "creates a daily task with defaults and builds today's occurrence" do
    status, payload = run_cli("tasks", "create", "--title", "Wipe slicer", "--list", @list.key, "--due-time", "16:00")

    assert_equal 0, status
    assert payload["ok"]
    task = payload.dig("data", "task")
    assert_equal "Wipe slicer", task["title"]
    assert_equal "daily", task["recurrence_type"]
    assert_equal Time.zone.today.iso8601, task["starts_on"]
    assert_equal "16:00", task["due_time"]
    assert_equal @list.key, task.dig("task_list", "key")

    record = Task.find(task["id"])
    assert record.task_occurrences.exists?(period_starts_on: Time.zone.today)
  end

  test "accepts weekday names for weekly tasks" do
    status, payload = run_cli(
      "tasks", "create", "--title", "Deep clean", "--list", @list.id.to_s,
      "--recurrence", "weekly", "--due-time", "09:00", "--weekdays", "mon,thu"
    )

    assert_equal 0, status
    assert_equal [ 1, 4 ], payload.dig("data", "task", "weekdays")
  end

  test "returns validation errors as JSON details" do
    status, payload = run_cli(
      "tasks", "create", "--title", "Broken", "--list", @list.key,
      "--recurrence", "weekly", "--due-time", "09:00"
    )

    assert_equal 1, status
    assert_not payload["ok"]
    assert_equal "Validation failed", payload["error"]
    assert payload["details"].any? { |message| message.include?("Weekdays") }
  end

  test "rejects an unknown task list with a helpful error" do
    status, payload = run_cli("tasks", "create", "--title", "X", "--list", "nope", "--due-time", "09:00")

    assert_equal 1, status
    assert_match(/No task list/, payload["error"])
  end

  test "updates only the provided attributes" do
    task = create_daily_task(title: "Old title")

    status, payload = run_cli("tasks", "update", task.id.to_s, "--title", "New title")

    assert_equal 0, status
    assert_equal "New title", payload.dig("data", "task", "title")
    assert_equal "16:00", task.reload.due_time.strftime("%H:%M")
  end

  test "update with no options fails" do
    task = create_daily_task

    status, payload = run_cli("tasks", "update", task.id.to_s)

    assert_equal 1, status
    assert_match(/Nothing to update/, payload["error"])
  end

  test "archives and reactivates a task" do
    task = create_daily_task

    status, payload = run_cli("tasks", "archive", task.id.to_s)
    assert_equal 0, status
    assert_not payload.dig("data", "task", "active")
    assert task.reload.archived?

    status, payload = run_cli("tasks", "reactivate", task.id.to_s)
    assert_equal 0, status
    assert payload.dig("data", "task", "active")
  end

  test "list filters by task list and active state" do
    active = create_daily_task(title: "Active task")
    archived = create_daily_task(title: "Archived task")
    archived.archive!
    other_list = TaskList.create!(name: "Closing")
    Task.create!(task_list: other_list, title: "Elsewhere", recurrence_type: "daily",
      starts_on: Time.zone.today, due_time: "10:00")

    _, payload = run_cli("tasks", "list", "--list", @list.key)
    titles = payload.dig("data", "tasks").map { |t| t["title"] }
    assert_includes titles, "Active task"
    assert_not_includes titles, "Archived task"
    assert_not_includes titles, "Elsewhere"

    _, payload = run_cli("tasks", "list", "--list", @list.key, "--archived")
    assert_equal [ "Archived task" ], payload.dig("data", "tasks").map { |t| t["title"] }
  end

  test "creates a task list with auto-assigned position" do
    status, payload = run_cli("task-lists", "create", "--name", "Closing")

    assert_equal 0, status
    list = payload.dig("data", "task_list")
    assert_equal "closing", list["key"]
    assert_operator list["position"], :>, @list.position
  end

  test "unknown resource and unknown action fail cleanly" do
    status, payload = run_cli("widgets", "list")
    assert_equal 1, status
    assert_match(/Unknown resource/, payload["error"])

    status, payload = run_cli("tasks", "explode")
    assert_equal 1, status
    assert_match(/Unknown action/, payload["error"])
  end

  private

  def run_cli(*argv)
    out = StringIO.new
    status = AgentCli::Runner.run(argv, out: out)
    [ status, JSON.parse(out.string) ]
  end

  def create_daily_task(title: "Task")
    Task.create!(task_list: @list, title: title, recurrence_type: "daily",
      starts_on: Time.zone.today, due_time: "16:00")
  end
end
