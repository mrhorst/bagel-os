require "test_helper"

class TaskListTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "upcoming_at? is false without a start time" do
    anytime = TaskList.new(name: "Anytime")
    assert_not anytime.upcoming_at?(Time.zone.parse("2026-05-18 10:00"))

    # An end-only window is either open or already past — never "upcoming".
    end_only = TaskList.new(name: "Morning", display_end_time: Time.zone.parse("11:00"))
    assert_not end_only.upcoming_at?(Time.zone.parse("2026-05-18 09:00"))
  end

  test "upcoming_at? is true before a future window opens" do
    list = TaskList.new(
      name: "Closing",
      display_start_time: Time.zone.parse("11:00"),
      display_end_time: Time.zone.parse("14:00")
    )

    assert list.upcoming_at?(Time.zone.parse("2026-05-18 10:30"))
    assert_not list.visible_at?(Time.zone.parse("2026-05-18 10:30"))
  end

  test "upcoming_at? is false once the window is open or already closed" do
    list = TaskList.new(
      name: "Closing",
      display_start_time: Time.zone.parse("11:00"),
      display_end_time: Time.zone.parse("14:00")
    )

    assert_not list.upcoming_at?(Time.zone.parse("2026-05-18 12:00")) # open now
    assert_not list.upcoming_at?(Time.zone.parse("2026-05-18 15:00")) # already closed
  end

  test "upcoming_at? handles overnight windows" do
    overnight = TaskList.new(
      name: "Late night",
      display_start_time: Time.zone.parse("22:00"),
      display_end_time: Time.zone.parse("02:00")
    )

    # Mid-afternoon: the window opens again at 22:00 tonight.
    assert overnight.upcoming_at?(Time.zone.parse("2026-05-18 15:00"))
    # After midnight, inside the open window: not upcoming.
    assert_not overnight.upcoming_at?(Time.zone.parse("2026-05-18 01:00"))
  end

  test "visible_ids_at and upcoming_ids_at partition active lists by window" do
    travel_to Time.zone.local(2026, 5, 18, 10, 30) do
      open_now = TaskList.create!(name: "Opening", position: 1)
      upcoming = TaskList.create!(
        name: "Closing",
        position: 2,
        display_start_time: Time.zone.parse("11:00"),
        display_end_time: Time.zone.parse("14:00")
      )
      archived = TaskList.create!(name: "Archived", position: 3, active: false)

      assert_includes TaskList.visible_ids_at, open_now.id
      assert_not_includes TaskList.visible_ids_at, upcoming.id
      assert_includes TaskList.upcoming_ids_at, upcoming.id
      assert_not_includes TaskList.upcoming_ids_at, open_now.id

      # Archived lists are out of scope for both.
      assert_not_includes TaskList.visible_ids_at, archived.id
      assert_not_includes TaskList.upcoming_ids_at, archived.id
    end
  end
end
