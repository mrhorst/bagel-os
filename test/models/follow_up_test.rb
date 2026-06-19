require "test_helper"

# Exercises the after_update_commit assignment callback. after_commit hooks do
# not fire under Rails' transactional tests (the wrapping transaction is rolled
# back, never committed), so this class commits for real and cleans up itself.
class FollowUpTest < ActiveJob::TestCase
  self.use_transactional_tests = false

  setup do
    @user = users(:one)
    @follow_up = FollowUp.create!(
      title: "Walk-in temp high", urgency: "normal", status: "open", opened_at: Time.current
    )
  end

  teardown { FollowUp.delete_all }

  test "assigning a follow-up enqueues a notification for the assignee" do
    assert_enqueued_with(job: Notifications::NewFollowUpAssignmentJob, args: [ @follow_up.id ]) do
      @follow_up.update!(assigned_to: @user)
    end
  end

  test "unassigning a follow-up does not enqueue a notification" do
    @follow_up.update!(assigned_to: @user)

    assert_no_enqueued_jobs only: Notifications::NewFollowUpAssignmentJob do
      @follow_up.update!(assigned_to: nil)
    end
  end

  test "editing an unrelated field does not enqueue a notification" do
    assert_no_enqueued_jobs only: Notifications::NewFollowUpAssignmentJob do
      @follow_up.update!(urgency: "urgent")
    end
  end
end
