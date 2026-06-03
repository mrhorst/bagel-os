require "test_helper"

class TasksLiveUpdatesTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "task state changes enqueue a delayed briefing refresh" do
    assert_enqueued_with(job: Tasks::GenerateBriefingJob) do
      Tasks::LiveUpdates.task_state_changed!
    end
  end
end
