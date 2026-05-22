require "test_helper"

class TasksCompletionWorkflowTest < ActiveSupport::TestCase
  test "completes a normal occurrence without photo evidence" do
    occurrence = task_occurrence(requires_photo_evidence: false)
    user = create_user("Demo Staff")

    completion = Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 11))).call(occurrence: occurrence, user: user, notes: "Done before lunch.")

    assert completion.persisted?
    assert_equal user, completion.user
    assert_equal "Demo Staff", completion.snapshot_staff_name
    assert_equal "Done before lunch.", completion.notes
    assert_equal "completed", occurrence.reload.status(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 11)))
  end

  test "photo-required occurrence rejects completion without photo" do
    occurrence = task_occurrence(requires_photo_evidence: true)
    user = create_user("Demo Staff")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 11))).call(occurrence: occurrence, user: user)
    end

    assert_includes error.record.errors[:photo], "is required for this task"
  end

  test "photo-required occurrence completes with one photo" do
    occurrence = task_occurrence(requires_photo_evidence: true)
    user = create_user("Demo Staff")

    completion = Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 11))).call(
      occurrence: occurrence,
      user: user,
      photo: photo_upload
    )

    assert completion.photo.attached?
  end

  test "normal occurrence rejects optional photo evidence" do
    occurrence = task_occurrence(requires_photo_evidence: false)
    user = create_user("Demo Staff")

    error = assert_raises(ActiveRecord::RecordInvalid) do
      Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 11))).call(
        occurrence: occurrence,
        user: user,
        photo: photo_upload
      )
    end

    assert_includes error.record.errors[:photo], "is only allowed for photo-required tasks"
  end

  test "missed recurring occurrence cannot be completed" do
    occurrence = task_occurrence(
      requires_photo_evidence: false,
      due_at: Time.zone.local(2026, 5, 17, 12),
      completion_window_ends_at: Time.zone.local(2026, 5, 18)
    )
    user = create_user("Demo Staff")

    error = assert_raises(ArgumentError) do
      Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 9))).call(occurrence: occurrence, user: user)
    end

    assert_equal "Missed tasks cannot be completed.", error.message
  end

  test "undo keeps photo evidence and allows same-day recompletion" do
    occurrence = task_occurrence(requires_photo_evidence: true)
    user = create_user("Demo Staff")
    manager = create_user("Demo Manager")
    completion = Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 11))).call(
      occurrence: occurrence,
      user: user,
      photo: photo_upload("first.jpg")
    )

    undone = Tasks::UndoCompletion.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 11, 5))).call(
      completion: completion,
      user: manager,
      note: "Wrong photo."
    )

    assert undone.undone?
    assert undone.photo.attached?
    assert_equal manager, undone.undone_by_user
    assert_equal "Demo Manager", undone.snapshot_undone_by_staff_name
    assert_equal "Wrong photo.", undone.undone_note
    assert_equal "late", occurrence.reload.status(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 12, 30)))

    corrected = Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 12, 30))).call(
      occurrence: occurrence,
      user: user,
      photo: photo_upload("corrected.jpg")
    )
    assert corrected.active?
    assert_equal 1, occurrence.task_completions.active.count
    assert_equal 1, occurrence.task_completions.undone.count
  end

  test "undo is rejected after the completion operating day" do
    occurrence = task_occurrence(requires_photo_evidence: false)
    user = create_user("Demo Staff")
    completion = Tasks::CompleteOccurrence.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 18, 11))).call(occurrence: occurrence, user: user)

    error = assert_raises(ArgumentError) do
      Tasks::UndoCompletion.new(operating_day: Tasks::OperatingDay.new(now: Time.zone.local(2026, 5, 19, 8))).call(completion: completion, user: user)
    end

    assert_equal "Completion can only be undone during the same operating day.", error.message
  end

  private

  def create_user(name)
    User.create!(
      email_address: "#{name.parameterize}-#{SecureRandom.hex(2)}@example.com",
      password: "password",
      name: name
    )
  end

  def task_occurrence(requires_photo_evidence:, due_at: Time.zone.local(2026, 5, 18, 12), completion_window_ends_at: Time.zone.local(2026, 5, 19))
    list = TaskList.create!(name: "Cleaning")
    task = list.tasks.create!(
      title: "Clean slicer",
      recurrence_type: "daily",
      starts_on: Date.new(2026, 5, 18),
      due_time: Time.zone.parse("12:00"),
      requires_photo_evidence: requires_photo_evidence
    )
    task.task_occurrences.create!(
      task_list: list,
      period_kind: "day",
      period_starts_on: due_at.to_date,
      period_ends_on: due_at.to_date,
      due_at: due_at,
      completion_window_ends_at: completion_window_ends_at,
      snapshot_title: task.title,
      snapshot_list_name: list.name,
      requires_photo_evidence: requires_photo_evidence
    )
  end

  def photo_upload(filename = "clean.jpg")
    {
      io: StringIO.new("fake image"),
      filename: filename,
      content_type: "image/jpeg"
    }
  end
end
