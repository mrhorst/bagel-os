require "test_helper"

# The home surface card must mirror the Tasks screen's notion of "today's
# work": it only counts tasks the user can actually reach right now, and it
# surfaces not-yet-open lists as a quiet "upcoming" hint.
class HomeDashboardTasksCardTest < ActionDispatch::IntegrationTest
  include ActiveSupport::Testing::TimeHelpers

  # Issue 1: a list whose display window already closed is unreachable on the
  # Tasks screen, so its incomplete tasks must not be flagged as "late" here.
  test "tasks in a closed-window list are not counted as late on the home card" do
    travel_to Time.zone.local(2026, 5, 18, 15) do
      build_daily_task(
        list_name: "Closing",
        due: "13:00",
        display_start: "12:00",
        display_end: "14:30"
      )

      get root_path

      assert_response :success
      assert_tasks_summary "All clear today"
      assert_tasks_not_urgent
    end
  end

  # Issue 2: a list that hasn't opened yet shows as a quiet "upcoming" count,
  # not as actionable "open today", and never turns the card urgent.
  test "tasks in a not-yet-open list show as upcoming, not open" do
    travel_to Time.zone.local(2026, 5, 18, 10, 30) do
      build_daily_task(
        list_name: "Closing",
        due: "13:00",
        display_start: "11:00",
        display_end: "14:30"
      )

      get root_path

      assert_response :success
      assert_tasks_summary "All clear now · 1 upcoming"
      assert_tasks_not_urgent
    end
  end

  # A visible late task still reports late; an upcoming list is appended as a
  # quiet suffix rather than folded into the live counts.
  test "visible late tasks report late with an upcoming suffix" do
    travel_to Time.zone.local(2026, 5, 18, 10, 30) do
      build_daily_task(list_name: "Opening", due: "08:00") # always visible, already late
      build_daily_task(
        list_name: "Closing",
        due: "13:00",
        display_start: "11:00",
        display_end: "14:30"
      )

      get root_path

      assert_response :success
      assert_tasks_summary "1 late, 1 open today · 1 upcoming"
      assert_select "a.home-surface-card-urgent[href=?]", tasks_root_path
    end
  end

  private

  def build_daily_task(list_name:, due:, display_start: nil, display_end: nil)
    list = TaskList.create!(
      name: list_name,
      position: TaskList.count + 1,
      display_start_time: (Time.zone.parse(display_start) if display_start),
      display_end_time: (Time.zone.parse(display_end) if display_end)
    )
    list.tasks.create!(
      title: "#{list_name} task",
      recurrence_type: "daily",
      starts_on: Date.new(2026, 5, 18),
      due_time: Time.zone.parse(due)
    )
    Tasks::OccurrenceBuilder.new.build!(from: Date.new(2026, 5, 18), to: Date.new(2026, 5, 18))
    list
  end

  def assert_tasks_summary(text)
    assert_select "a[href=?] .home-surface-card-summary", tasks_root_path, text: text
  end

  def assert_tasks_not_urgent
    assert_select "a.home-surface-card-urgent[href=?]", tasks_root_path, count: 0
  end
end
