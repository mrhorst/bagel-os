require "test_helper"
require "rake"

class AdminTasksTest < ActiveSupport::TestCase
  setup do
    Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
    Rake.application.rake_require("tasks/admin", [ Rails.root.join("lib").to_s ]) unless Rake::Task.task_defined?("admin:create")
    @task = Rake::Task["admin:create"]
    @previous_env = ENV.to_h.slice("EMAIL", "PASSWORD", "NAME")
    User.delete_all
  end

  teardown do
    @task.reenable
    %w[EMAIL PASSWORD NAME].each { |key| ENV.delete(key) }
    @previous_env.each { |key, value| ENV[key] = value }
  end

  test "creates the first admin as owner" do
    ENV["EMAIL"] = "Owner@Example.com"
    ENV["PASSWORD"] = "secret123"
    ENV["NAME"] = "Owner"

    assert_difference -> { User.count }, 1 do
      capture_io { @task.invoke }
    end

    user = User.find_by!(email_address: "owner@example.com")
    assert user.admin?
    assert user.owner?
    assert user.authenticate("secret123")
    assert_equal "Owner", user.name
  end

  test "creates later admins without taking ownership" do
    User.create!(email_address: "existing@example.com", password: "secret123", role: :admin, owner: true)
    ENV["EMAIL"] = "manager@example.com"
    ENV["PASSWORD"] = "secret456"

    assert_difference -> { User.count }, 1 do
      capture_io { @task.invoke }
    end

    user = User.find_by!(email_address: "manager@example.com")
    assert user.admin?
    refute user.owner?
  end
end
