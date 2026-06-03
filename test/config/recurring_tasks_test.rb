require "test_helper"
require "erb"
require "yaml"

class RecurringTasksTest < ActiveSupport::TestCase
  test "production refreshes task briefings hourly" do
    config = YAML.safe_load(ERB.new(Rails.root.join("config/recurring.yml").read).result)
    task = config.fetch("production").fetch("generate_task_briefing")

    assert_equal "Tasks::GenerateBriefingJob", task.fetch("class")
    assert_equal "background", task.fetch("queue")
    assert_equal "every hour at minute 5", task.fetch("schedule")
  end
end
