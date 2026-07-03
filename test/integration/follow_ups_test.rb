require "test_helper"

class FollowUpsTest < ActionDispatch::IntegrationTest
  test "open tab lists open follow-ups by urgency" do
    seed_follow_ups

    get follow_ups_path
    assert_response :success

    assert_select ".follow-ups-tab.active", text: /Open/
    assert_select ".follow-up-card h2", text: "Walk-in warm"
    assert_select ".follow-up-card h2", text: "Maintenance"
    # Resolved shouldn't show on the open tab.
    assert_select ".follow-up-card h2", text: "Old issue", count: 0
  end

  test "open empty state offers a path to the Log Book instead of a dead end" do
    # No open follow-ups: the empty state tells the user to "flag a Log Book
    # note", so it must give them a way to get there rather than stranding them.
    assert_equal 0, FollowUp.open.count

    get follow_ups_path
    assert_response :success
    assert_select ".empty-state a.button[href=?]", log_book_path, text: /Log Book/
  end

  test "resolved empty state stays informational with no create CTA" do
    # The resolved tab is a passive archive — nothing to create from here, so it
    # must not sprout the open tab's Log Book call to action.
    assert_equal 0, FollowUp.resolved.count

    get follow_ups_path(scope: "resolved")
    assert_response :success
    assert_select ".empty-state a.button", count: 0
  end

  test "resolved tab lists resolved follow-ups" do
    seed_follow_ups

    get follow_ups_path(scope: "resolved")
    assert_response :success
    assert_select ".follow-up-card h2", text: "Old issue"
  end

  test "browsing the resolved tab and opening an item returns Back to the resolved tab, not Open" do
    # A manager auditing the Resolved archive taps an item, reads it, and taps
    # "Back to Follow-ups". The detail page's back affordance must return them to
    # the tab they were on (Resolved) instead of dumping them on the default Open
    # tab and losing their place. The tab is carried as ?scope= through the card
    # link into the detail page's back href.
    seed_follow_ups
    resolved = FollowUp.resolved.first

    # The resolved-tab card links into the detail page carrying the active tab.
    get follow_ups_path(scope: "resolved")
    assert_response :success
    assert_select ".follow-up-card[href=?]", follow_up_path(resolved, scope: "resolved")

    # Reached with that scope, the back affordance points back at the Resolved tab.
    get follow_up_path(resolved, scope: "resolved")
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", follow_ups_path(scope: "resolved")
  end

  test "Back from a detail page reached without a tab falls through to the default list" do
    # A deep link / bookmark with no scope must still produce a valid Back target
    # (the default Open list), not a malformed href.
    follow_up = FollowUp.create!(title: "Door squeaks", urgency: "normal", opened_at: 1.hour.ago, opened_by: users(:one))

    get follow_up_path(follow_up)
    assert_response :success
    assert_select "a.mobile-header-back[href=?]", follow_ups_path
  end

  test "resolving updates the record" do
    follow_up = FollowUp.create!(title: "Door squeaks", urgency: "normal", opened_at: 1.hour.ago, opened_by: users(:one))

    patch resolve_follow_up_path(follow_up), params: { resolution_note: "Oiled the hinge", resolved_via: "action_taken" }
    assert_redirected_to follow_ups_path

    follow_up.reload
    assert follow_up.resolved?
    assert_equal "Oiled the hinge", follow_up.resolution_note
    assert_equal "action_taken", follow_up.resolved_via
  end

  test "reopening a resolved follow-up is guarded by a confirmation that names the lost note" do
    # Reopen clears the resolution — outcome, who/when, and the typed note — and on
    # mobile it's a single unguarded tap right beside that note. It must carry the
    # same confirmation guard every other irreversible control in the app uses, and
    # say what gets discarded.
    follow_up = FollowUp.create!(title: "Door squeaks", urgency: "normal", opened_at: 2.hours.ago, opened_by: users(:one),
                                 status: "resolved", resolved_at: 1.hour.ago, resolved_by: users(:one),
                                 resolved_via: "action_taken", resolution_note: "Oiled the hinge")

    get follow_up_path(follow_up)
    assert_response :success
    assert_select "form[action=?][data-turbo-confirm]", reopen_follow_up_path(follow_up)
    assert_select "form[action=?][data-turbo-confirm*=?]", reopen_follow_up_path(follow_up), "resolution note will be cleared"
  end

  test "reopen confirmation drops the note warning when there is no resolution note" do
    follow_up = FollowUp.create!(title: "Door squeaks", urgency: "normal", opened_at: 2.hours.ago, opened_by: users(:one),
                                 status: "resolved", resolved_at: 1.hour.ago, resolved_by: users(:one),
                                 resolved_via: "action_taken")

    get follow_up_path(follow_up)
    assert_response :success
    # Still guarded, but no false claim that a (non-existent) note will be lost.
    assert_select "form[action=?][data-turbo-confirm]", reopen_follow_up_path(follow_up)
    assert_select "form[action=?][data-turbo-confirm*=?]", reopen_follow_up_path(follow_up), "resolution note", count: 0
  end

  test "posting a note appends to the thread" do
    follow_up = FollowUp.create!(title: "Walk-in warm", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one))

    assert_difference -> { follow_up.notes.count }, 1 do
      post follow_up_notes_path(follow_up), params: { follow_up_note: { body: "Called the technician." } }
    end
    assert_redirected_to follow_up_path(follow_up)

    follow_up.reload
    note = follow_up.notes.last
    assert_equal "Called the technician.", note.body
    assert_equal users(:one), note.author
  end

  test "a resolved follow-up still shows the note form and accepts a note without disturbing the resolution" do
    # You must be able to annotate a closed item ("customer called back, all good")
    # without reopening it — reopening discards the whole resolution. The note thread
    # is append-only for the life of the item. (#388)
    follow_up = FollowUp.create!(title: "Walk-in warm", urgency: "urgent", opened_at: 2.hours.ago, opened_by: users(:one),
                                 status: "resolved", resolved_at: 1.hour.ago, resolved_by: users(:one),
                                 resolved_via: "action_taken", resolution_note: "Swapped the thermostat")

    # The form renders on the resolved detail page, not just for open items.
    get follow_up_path(follow_up)
    assert_response :success
    assert_select "form.follow-up-note-form textarea[name='follow_up_note[body]']"

    assert_difference -> { follow_up.notes.count }, 1 do
      post follow_up_notes_path(follow_up), params: { follow_up_note: { body: "Customer called back, all good." } }
    end
    assert_redirected_to follow_up_path(follow_up)

    follow_up.reload
    # The note landed, and the resolution metadata is untouched.
    assert_equal "Customer called back, all good.", follow_up.notes.last.body
    assert_equal "resolved", follow_up.status
    assert_equal "action_taken", follow_up.resolved_via
    assert_equal "Swapped the thermostat", follow_up.resolution_note
    assert_equal users(:one), follow_up.resolved_by
  end

  test "empty note body is rejected" do
    follow_up = FollowUp.create!(title: "Door squeaks", urgency: "normal", opened_at: 1.hour.ago, opened_by: users(:one))

    assert_no_difference -> { follow_up.notes.count } do
      post follow_up_notes_path(follow_up), params: { follow_up_note: { body: "" } }
    end
  end

  test "a failed note re-renders the page in place with the error shown, instead of redirecting away" do
    follow_up = FollowUp.create!(title: "Door squeaks", urgency: "normal", opened_at: 1.hour.ago, opened_by: users(:one))

    # A whitespace-only body slips past the textarea's HTML5 `required` but fails
    # the model's presence validation. Rather than bouncing the reviewer to a
    # fresh page with a detached banner (dropping what they typed), the note form
    # should recover in place the way the spawn-task form on this same page does.
    assert_no_difference -> { follow_up.notes.count } do
      post follow_up_notes_path(follow_up), params: { follow_up_note: { body: "   \n  " } }
    end

    # Re-rendered in place (not redirected away), with the error inline by the form.
    assert_response :unprocessable_entity
    assert_select "form.follow-up-note-form .form-errors", text: /blank/i
    # The note thread and the rest of the detail page still render.
    assert_select "h1", text: "Door squeaks"
  end

  test "assign sets the assignee" do
    follow_up = FollowUp.create!(title: "Walk-in warm", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one))
    patch assign_follow_up_path(follow_up), params: { assigned_to_id: users(:two).id }
    assert_redirected_to follow_up_path(follow_up)
    assert_equal users(:two), follow_up.reload.assigned_to
  end

  test "unassign clears the assignee" do
    follow_up = FollowUp.create!(title: "Walk-in warm", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one), assigned_to: users(:two))
    patch assign_follow_up_path(follow_up), params: { assigned_to_id: "" }
    assert_nil follow_up.reload.assigned_to
  end

  test "spawn one-shot task creates a Task in the system list and links it" do
    follow_up = FollowUp.create!(title: "Toilet clogged", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one))

    assert_difference -> { Task.count }, 1 do
      assert_difference -> { FollowUpTaskLink.count }, 1 do
        post spawn_task_follow_up_path(follow_up),
          params: { spawn: { title: "Snake the toilet", link_kind: "one_shot", due_time: "17:00", auto_resolve: "1" } }
      end
    end

    task = Task.last
    assert_equal "Snake the toilet", task.title
    assert_equal "one_time", task.recurrence_type
    assert_equal "Follow-up tasks", task.task_list.name
    assert follow_up.reload.resolved?
    assert_equal "converted_to_task", follow_up.resolved_via
  end

  test "spawn recurring task lives in the chosen list" do
    follow_up = FollowUp.create!(title: "Clean sink", urgency: "normal", opened_at: 1.hour.ago, opened_by: users(:one))
    list = TaskList.create!(name: "Cleaning", position: 1)

    post spawn_task_follow_up_path(follow_up),
      params: { spawn: { title: "Clean bathroom sink", link_kind: "recurring", recurrence_type: "daily", task_list_id: list.id, due_time: "17:00" } }

    task = Task.last
    assert_equal "daily", task.recurrence_type
    assert_equal list, task.task_list
    refute follow_up.reload.resolved?
  end

  test "a failed spawn re-renders the form with the typed input preserved instead of dropping it" do
    follow_up = FollowUp.create!(title: "Fix walk-in", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one))
    list = TaskList.create!(name: "Cleaning", position: 1)

    # Weekly recurrence with no weekday checked is an easy mis-step — unchecked
    # boxes send no param — and fails validation. The user should not lose the
    # title and instructions they typed.
    assert_no_difference -> { Task.count } do
      post spawn_task_follow_up_path(follow_up),
        params: { spawn: { title: "My carefully typed title", description: "Lots of typed notes",
                           link_kind: "recurring", recurrence_type: "weekly", task_list_id: list.id,
                           due_time: "08:30", auto_resolve: "0" } }
    end

    # Re-rendered in place (not redirected away), so the form survives.
    assert_response :unprocessable_entity
    assert_select ".form-errors", text: /at least one day/i
    # The disclosure is reopened so the repopulated form is visible.
    assert_select "details.follow-up-spawn[open]"
    # Everything the user typed/chose is preserved.
    assert_select "input[name='spawn[title]'][value='My carefully typed title']"
    assert_select "textarea[name='spawn[description]']", text: /Lots of typed notes/
    assert_select "select[name='spawn[link_kind]'] option[selected][value=recurring]"
    assert_select "select[name='spawn[recurrence_type]'] option[selected][value=weekly]"
    assert_select "input[name='spawn[due_time]'][value='08:30']"
  end

  test "a spawned task is reachable from the follow-up that created it" do
    follow_up = FollowUp.create!(title: "Toilet clogged", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one))

    # auto_resolve off so the follow-up stays open and we render its detail plainly.
    post spawn_task_follow_up_path(follow_up),
      params: { spawn: { title: "Snake the toilet", link_kind: "one_shot", due_time: "17:00", auto_resolve: "0" } }
    task = Task.last

    get follow_up_path(follow_up)
    assert_response :success
    # The "Tasks spawned" list must link the task to its definition — otherwise the
    # user can see what they created but has no way to reach it. The link carries
    # origin=follow_up so the edit page's back arrow returns here rather than
    # stranding the user in the Settings management tree.
    assert_select ".follow-up-task-links a[href=?]",
      edit_tasks_manage_task_path(task, origin: "follow_up", follow_up_id: follow_up.id),
      text: /Snake the toilet/
  end

  test "free-text blocks wrap simple_format in a block container so its paragraphs nest validly" do
    # simple_format emits its own <p>…</p>. Wrapping that in another <p> is invalid
    # HTML — the browser (and Nokogiri) splits the nesting, leaving the styled
    # container as an empty paragraph and dropping the text into an unstyled
    # sibling, so `.follow-up-note-body p { margin: 0 }` never matches and a stray
    # blank line renders above the text. The wrapper must be a block container.
    follow_up = FollowUp.create!(title: "Walk-in warm", urgency: "urgent", opened_at: 1.hour.ago, opened_by: users(:one),
                                 description: "Door left ajar overnight.",
                                 status: "resolved", resolved_at: 1.hour.ago, resolved_by: users(:one),
                                 resolved_via: "action_taken", resolution_note: "Latch adjusted.")
    follow_up.notes.create!(body: "Checked at 2pm, still warm.", author: users(:one))

    get follow_up_path(follow_up)
    assert_response :success

    # The note text must live INSIDE the styled container, not split into a sibling.
    assert_select ".follow-up-note-body p", text: "Checked at 2pm, still warm."
    # The container must not be a <p> (which can't legally hold simple_format's <p>).
    assert_select "p.follow-up-note-body", count: 0
    # The description and resolution-note blocks carry the same fix.
    assert_select "div > p", text: "Door left ajar overnight."
    assert_select ".follow-up-detail-resolved div > p", text: "Latch adjusted."
  end

  test "employee without permission is redirected" do
    employee = users(:two)
    sign_in_as(employee)

    get follow_ups_path
    assert_redirected_to root_path

    employee.grant_module("follow_ups")
    get follow_ups_path
    assert_response :success
  end

  private

  def seed_follow_ups
    FollowUp.create!(title: "Walk-in warm", urgency: "urgent",   opened_at: 30.minutes.ago, opened_by: users(:one))
    FollowUp.create!(title: "Maintenance",  urgency: "normal",   opened_at: 1.hour.ago,      opened_by: users(:one))
    FollowUp.create!(title: "Old issue",    urgency: "important", opened_at: 1.day.ago,      opened_by: users(:one),
                     status: "resolved", resolved_at: 1.hour.ago, resolved_by: users(:one), resolved_via: "action_taken")
  end
end
