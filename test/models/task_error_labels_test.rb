require "test_helper"

class TaskErrorLabelsTest < ActiveSupport::TestCase
  # A failed task save must name fields using the words the manager sees on the
  # edit/guided forms, not the raw column names. The forms label these inputs
  # "Task name", "Repeats", "Date", "Start date", "Weekly days", and "Sort
  # order" — so the validation errors must say the same, or the manager is told
  # to fix a field that isn't on screen ("One time on is required", "Position is
  # not a number"). Mirrors LogBookSectionTest and the en.yml mapping.
  setup { @list = TaskList.create!(name: "Prep", position: 1, active: true) }

  test "blank title and recurrence speak the form labels, not raw columns" do
    messages = errors_for(Task.new(task_list_id: @list.id, recurrence_type: ""))

    assert_includes messages, "Task name can't be blank"
    assert_includes messages, "Repeats can't be blank"
    refute_leaks messages, %w[Title Recurrence\ type]
  end

  test "one-time date and time use the labels 'Date' and 'Due time'" do
    messages = errors_for(Task.new(task_list_id: @list.id, recurrence_type: "one_time"))

    assert_includes messages, "Date is required"
    assert_includes messages, "Due time is required"
    refute_leaks messages, ["One time on"]
  end

  test "weekly day requirement is named 'Weekly days' to match the form" do
    messages = errors_for(Task.new(
      task_list_id: @list.id, recurrence_type: "weekly",
      starts_on: Date.current, due_time: Time.zone.parse("10:00"), weekdays: []
    ))

    assert_includes messages, "Weekly days must include at least one day"
    refute_leaks messages, ["Weekdays"]
  end

  test "a blank sort order is named 'Sort order', not the raw 'Position'" do
    messages = errors_for(Task.new(
      task_list_id: @list.id, recurrence_type: "daily",
      starts_on: Date.current, due_time: Time.zone.parse("10:00"), position: nil
    ))

    assert_includes messages, "Sort order is not a number"
    refute_leaks messages, ["Position"]
  end

  private

  def errors_for(task)
    task.valid?
    task.errors.full_messages
  end

  def refute_leaks(messages, raw_names)
    joined = messages.join(" | ")
    raw_names.each do |raw|
      refute_includes joined, "#{raw} ", "error leaked raw attribute name #{raw.inspect}"
    end
  end
end
