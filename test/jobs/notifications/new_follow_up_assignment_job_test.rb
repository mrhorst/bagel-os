require "test_helper"

module Notifications
  class NewFollowUpAssignmentJobTest < ActiveJob::TestCase
    include PushNotificationTestHelper

    setup do
      @assignee = users(:one) # admin → can access :follow_ups
      @assignee.push_subscriptions.create!(
        endpoint: "https://push.example.com/admin", p256dh_key: "p", auth_key: "a"
      )
    end

    test "pushes the assignee a deep-linked notification" do
      follow_up = create_follow_up(assigned_to: @assignee)

      sent = capture_push_notifications { NewFollowUpAssignmentJob.perform_now(follow_up.id) }

      assert_equal 1, sent.size
      assert_equal "Follow-up assigned to you", sent.first[:title]
      assert_equal "Walk-in temp high.", sent.first[:body]
      assert_equal "/follow-ups/#{follow_up.id}", sent.first[:url]
      assert_equal "follow-up-#{follow_up.id}", sent.first[:tag]
    end

    test "spells out the urgency when it is not normal" do
      follow_up = create_follow_up(assigned_to: @assignee, urgency: "urgent")

      sent = capture_push_notifications { NewFollowUpAssignmentJob.perform_now(follow_up.id) }

      assert_equal "Walk-in temp high — marked urgent.", sent.first[:body]
    end

    test "skips an assignee who cannot access the follow-ups module" do
      employee = users(:two) # plain employee, no follow_ups permission
      employee.push_subscriptions.create!(
        endpoint: "https://push.example.com/employee", p256dh_key: "p", auth_key: "a"
      )
      follow_up = create_follow_up(assigned_to: employee)

      sent = capture_push_notifications { NewFollowUpAssignmentJob.perform_now(follow_up.id) }

      assert_empty sent
    end

    test "does nothing when the follow-up has no assignee" do
      follow_up = create_follow_up(assigned_to: nil)

      sent = capture_push_notifications { NewFollowUpAssignmentJob.perform_now(follow_up.id) }

      assert_empty sent
    end

    test "does nothing when the follow-up no longer exists" do
      sent = capture_push_notifications { NewFollowUpAssignmentJob.perform_now(-1) }

      assert_empty sent
    end

    private

    def create_follow_up(assigned_to:, urgency: "normal")
      FollowUp.create!(
        title: "Walk-in temp high",
        urgency: urgency,
        status: "open",
        opened_at: Time.current,
        assigned_to: assigned_to
      )
    end
  end
end
