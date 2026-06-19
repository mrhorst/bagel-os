require "test_helper"

module Notifications
  class LateTasksJobTest < ActiveJob::TestCase
    include ActiveSupport::Testing::TimeHelpers
    include PushNotificationTestHelper

    setup do
      @admin = users(:one) # owner/admin → in the :tasks audience
      @admin.push_subscriptions.create!(
        endpoint: "https://push.example.com/admin", p256dh_key: "p", auth_key: "a"
      )
    end

    test "pushes a deep-linked notification for a single late task and stamps it" do
      occurrence = nil
      sent = []

      travel_to Time.zone.local(2026, 5, 18, 9) do
        occurrence = build_late_task("Check display case", due: "08:00")

        sent = capture_push_notifications do
          LateTasksJob.perform_now(now: Time.current)
        end
      end

      assert_equal 1, sent.size
      assert_equal "Check display case is late", sent.first[:title]
      assert_equal "tasks-late", sent.first[:tag]
      assert_equal "/tasks/occurrences/#{occurrence.id}", sent.first[:url]
      assert_match "was due at 8:00 AM", sent.first[:body]
      assert_not_nil occurrence.reload.late_notified_at
    end

    test "never announces the same late task twice" do
      travel_to Time.zone.local(2026, 5, 18, 9) do
        build_late_task("Check display case", due: "08:00")

        capture_push_notifications { LateTasksJob.perform_now(now: Time.current) }
        second_run = capture_push_notifications { LateTasksJob.perform_now(now: Time.current) }

        assert_empty second_run
      end
    end

    test "summarizes several late tasks into a digest pointing at the dashboard" do
      sent = []

      travel_to Time.zone.local(2026, 5, 18, 9) do
        build_late_task("Check display case", due: "08:00")
        build_late_task("Sanitize slicer", due: "08:30")

        sent = capture_push_notifications { LateTasksJob.perform_now(now: Time.current) }
      end

      assert_equal 1, sent.size
      assert_equal "2 tasks are late", sent.first[:title]
      assert_equal "/tasks", sent.first[:url]
      assert_match "Check display case and Sanitize slicer", sent.first[:body]
    end

    test "stays silent during quiet hours" do
      occurrence = nil
      sent = []

      travel_to Time.zone.local(2026, 5, 18, 23) do
        occurrence = build_late_task("Lock up", due: "20:00")

        sent = capture_push_notifications { LateTasksJob.perform_now(now: Time.current) }
      end

      assert_empty sent
      assert_nil occurrence.reload.late_notified_at, "must not stamp tasks it didn't announce"
    end

    test "does nothing when Web Push is not configured" do
      travel_to Time.zone.local(2026, 5, 18, 9) do
        occurrence = build_late_task("Check display case", due: "08:00")

        # No capture stub → WebPushConfig.configured? is its real (false) self.
        assert_nothing_raised { LateTasksJob.perform_now(now: Time.current) }
        assert_nil occurrence.reload.late_notified_at
      end
    end

    private

    # Build today's occurrence for a daily task due earlier than `now`, so it is
    # already late but still inside its completion window.
    def build_late_task(title, due:)
      list = TaskList.create!(name: "Opening-#{title.parameterize}", position: 1)
      list.tasks.create!(
        title: title,
        recurrence_type: "daily",
        starts_on: Date.current,
        due_time: Time.zone.parse(due)
      )
      Tasks::OccurrenceBuilder.new(operating_day: Tasks::OperatingDay.new(now: Time.current))
        .build!(from: Date.current, to: Date.current)

      TaskOccurrence.find_by!(snapshot_title: title)
    end
  end
end
