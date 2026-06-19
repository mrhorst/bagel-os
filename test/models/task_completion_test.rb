require "test_helper"
require "stringio"

class TaskCompletionTest < ActiveSupport::TestCase
  setup do
    @list = TaskList.create!(name: "Closing")
    @task = @list.tasks.create!(
      title: "Lock up",
      recurrence_type: "daily",
      starts_on: Date.new(2026, 6, 1),
      due_time: Time.zone.parse("22:00")
    )
  end

  def occurrence(requires_photo:)
    # Each occurrence needs a distinct period — a task can't have two for the
    # same day (uniqueness on task_id + period_kind + period_starts_on).
    @day_seq = (@day_seq || 0) + 1
    day = Date.new(2026, 6, 1) + @day_seq.days
    @task.task_occurrences.create!(
      task_list: @list, period_kind: "day",
      period_starts_on: day, period_ends_on: day,
      snapshot_title: @task.title, snapshot_list_name: @list.name,
      requires_photo_evidence: requires_photo
    )
  end

  def build_completion(occ, **attrs)
    occ.task_completions.build({ user: users(:one), snapshot_staff_name: "Sam", completed_at: Time.current }.merge(attrs))
  end

  test "valid without a photo when the task doesn't require one" do
    assert build_completion(occurrence(requires_photo: false)).valid?
  end

  test "requires a photo when the occurrence demands evidence" do
    completion = build_completion(occurrence(requires_photo: true))

    assert_not completion.valid?
    assert_includes completion.errors[:photo], "is required for this task"
  end

  test "rejects a photo when the task does not allow one" do
    completion = build_completion(occurrence(requires_photo: false))
    completion.photo.attach(io: StringIO.new("fake-image"), filename: "proof.png", content_type: "image/png")

    assert_not completion.valid?
    assert_includes completion.errors[:photo], "is only allowed for photo-required tasks"
  end

  test "requires a staff name and completion time" do
    assert_not build_completion(occurrence(requires_photo: false), snapshot_staff_name: nil).valid?
    assert_not build_completion(occurrence(requires_photo: false), completed_at: nil).valid?
  end

  test "active and undone scopes track the undo state" do
    completion = build_completion(occurrence(requires_photo: false))
    completion.save!

    assert completion.active?
    assert_includes TaskCompletion.active, completion

    completion.update!(undone_at: Time.current, undone_by_user: users(:two))

    assert completion.undone?
    assert_includes TaskCompletion.undone, completion
    assert_not_includes TaskCompletion.active, completion
  end
end
