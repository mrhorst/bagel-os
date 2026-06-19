require "test_helper"

class TasksOperatingDayTest < ActiveSupport::TestCase
  NOON = Time.zone.local(2026, 6, 15, 12)

  def operating_day(now = NOON)
    Tasks::OperatingDay.new(now: now)
  end

  test "passed? is true only for moments at or before now" do
    day = operating_day

    assert day.passed?(NOON - 1.hour)
    assert day.passed?(NOON)
    assert_not day.passed?(NOON + 1.hour)
    assert_not day.passed?(nil)
  end

  test "today and same_day_as? use the calendar day of now" do
    day = operating_day

    assert_equal Date.new(2026, 6, 15), day.today
    assert day.same_day_as?(NOON + 11.hours)            # 11pm same day
    assert_not day.same_day_as?(NOON + 13.hours)        # 1am next day
    assert_not day.same_day_as?(nil)
  end

  test "window_end_for closes a date at the following midnight" do
    assert_equal Time.zone.local(2026, 6, 16), operating_day.window_end_for(Date.new(2026, 6, 15))
  end

  test "from wraps a time and passes an existing operating day through" do
    assert_instance_of Tasks::OperatingDay, Tasks::OperatingDay.from(nil)

    existing = operating_day
    assert_same existing, Tasks::OperatingDay.from(existing)
  end
end
