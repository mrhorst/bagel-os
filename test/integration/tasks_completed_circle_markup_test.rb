require "test_helper"

# The completion circle on the focused list / dashboard renders as a real submit
# <button>. An empty `do; end` block made FormBuilder#button fall back to its
# default "Button" label; hidden by `color: transparent` it still sat in the
# 30px flex circle and shoved the ::after checkmark off-center, so a freshly
# completed task showed an "ugly" half-rendered tick until a full reload.
#
# These assert the swapped-in markup is clean: the completion circle carries no
# stray label text, so nothing can displace the checkmark glyph.
class TasksCompletedCircleMarkupTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:one) }

  test "the completed circle returned by the Turbo stream carries no leaked label text" do
    occurrence = open_occurrence_today

    post tasks_occurrence_completion_path(occurrence),
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success

    button = completion_circle_button(response.body)
    assert button, "expected a completed task-checkbox button in the Turbo stream"
    assert_includes button["class"], "task-checkbox-completed"
    assert_equal "", button.text.strip,
      "the completion circle must render no visible label — stray text displaces the checkmark glyph"
  end

  test "the open circle carries no leaked label text" do
    occurrence = open_occurrence_today

    get tasks_list_path(occurrence.task_list)
    assert_response :success

    button = Nokogiri::HTML(response.body).at_css("button.task-checkbox-open")
    assert button, "expected an open task-checkbox button on the focused list"
    assert_equal "", button.text.strip,
      "the open circle must render no visible label"
  end

  private

  def completion_circle_button(body)
    # The Turbo stream wraps the row partial in <template>; parse its contents.
    doc = Nokogiri::HTML(body)
    template = doc.at_css("turbo-stream[target^='task_occurrence'] template")
    fragment = Nokogiri::HTML.fragment(template.inner_html)
    fragment.at_css("button.task-checkbox-completed")
  end

  def open_occurrence_today
    list = TaskList.create!(name: "Cleaning")
    task = list.tasks.create!(
      title: "Clean slicer",
      recurrence_type: "daily",
      starts_on: Date.current,
      due_time: Time.zone.parse("23:59"),
      requires_photo_evidence: false
    )
    task.task_occurrences.create!(
      task_list: list,
      period_kind: "day",
      period_starts_on: Date.current,
      period_ends_on: Date.current,
      due_at: 1.hour.from_now,
      completion_window_ends_at: 1.week.from_now,
      snapshot_title: task.title,
      snapshot_list_name: list.name,
      requires_photo_evidence: false
    )
  end
end
