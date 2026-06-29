require "test_helper"

module Agents
  # Covers the voice-driven authoring slice: creating task lists, tasks, and
  # inventory items, plus the reads that resolve where to file them.
  class AuthoringTest < ActiveSupport::TestCase
    include AgentCliTestHelper

    setup { authenticate_agent!(User.create!(email_address: "author@example.com", name: "Author", password: "password123", role: :admin)) }
    teardown { deauthenticate_agent! }

    test "tasks:create-list creates a list and derives its key from the name" do
      status, json, = run_cli("tasks:create-list", "--name", "Closing Duties")
      assert_equal 0, status
      assert_equal true, json.dig("data", "created")
      assert_equal "closing-duties", json.dig("data", "task_list", "key")
      assert TaskList.exists?(name: "Closing Duties")
    end

    test "tasks:create-list --dry-run does not write" do
      status, json, = run_cli("tasks:create-list", "--name", "Maybe Later", "--dry-run")
      assert_equal 0, status
      assert_equal true, json.dig("data", "dry_run")
      assert_not TaskList.exists?(name: "Maybe Later")
    end

    test "a duplicate list name is a usage error (unique key)" do
      TaskList.create!(name: "Opening", key: "opening", position: 1)
      status, _json, err = run_cli("tasks:create-list", "--name", "Opening")
      assert_equal 1, status
      assert_equal "usage_error", err.dig("error", "type")
    end

    test "tasks:create files a daily task into a list and materializes occurrences" do
      list = TaskList.create!(name: "Closing", key: "closing", position: 1)

      status, json, = run_cli("tasks:create", "--list", "Closing", "--title", "Lock the doors", "--due-time", "22:00")
      assert_equal 0, status
      assert_equal true, json.dig("data", "created")
      task = Task.find(json.dig("data", "task", "id"))
      assert_equal list, task.task_list
      assert_equal "daily", task.recurrence_type
      assert task.task_occurrences.where(period_starts_on: Date.current).exists?
    end

    test "tasks:create resolves the list by id too" do
      list = TaskList.create!(name: "Prep", key: "prep", position: 1)
      status, json, = run_cli("tasks:create", "--list", list.id.to_s, "--title", "Slice tomatoes", "--due-time", "08:00")
      assert_equal 0, status
      assert_equal list.id, Task.find(json.dig("data", "task", "id")).task_list_id
    end

    test "a weekly task without weekdays is a usage error" do
      TaskList.create!(name: "Cleaning", key: "cleaning", position: 1)
      status, _json, err = run_cli("tasks:create", "--list", "Cleaning", "--title", "Deep clean", "--recurrence", "weekly", "--due-time", "23:00")
      assert_equal 1, status
      assert_equal "usage_error", err.dig("error", "type")
    end

    test "tasks:create with a weekly recurrence and weekdays succeeds" do
      TaskList.create!(name: "Cleaning", key: "cleaning", position: 1)
      status, json, = run_cli("tasks:create", "--list", "Cleaning", "--title", "Mop", "--recurrence", "weekly", "--due-time", "23:00", "--weekdays", "1,3,5")
      assert_equal 0, status
      assert_equal [ 1, 3, 5 ], json.dig("data", "task", "weekdays")
    end

    test "tasks:create into a missing list is not_found" do
      status, _json, err = run_cli("tasks:create", "--list", "Nope", "--title", "x", "--due-time", "09:00")
      assert_equal 1, status
      assert_equal "not_found", err.dig("error", "type")
    end

    test "tasks:lists reports active task counts" do
      list = TaskList.create!(name: "Prep", key: "prep", position: 1)
      Task.create!(task_list: list, title: "Slice", recurrence_type: "daily", starts_on: Date.current, due_time: "08:00", position: 0)

      _status, json, = run_cli("tasks:lists")
      row = json.dig("data", "lists").find { |l| l["name"] == "Prep" }
      assert_equal 1, row["active_task_count"]
    end

    test "inventory:add-item creates an item and the section if new" do
      status, json, = run_cli("inventory:add-item", "--name", "Scallion cream cheese", "--section", "Walk-in", "--guide-frequency", "weekly")
      assert_equal 0, status
      assert_equal true, json.dig("data", "created")
      assert_equal "Walk-in", json.dig("data", "inventory_item", "section")
      assert InventorySection.exists?(name: "Walk-in")
      assert_equal "scallion-cream-cheese", json.dig("data", "inventory_item", "key")
    end

    test "inventory:add-item reuses an existing section by name (case-insensitive)" do
      section = InventorySection.create!(name: "Dry Storage")
      _status, json, = run_cli("inventory:add-item", "--name", "Flour", "--section", "dry storage")
      assert_equal section.id, InventoryItem.find(json.dig("data", "inventory_item", "id")).inventory_section_id
    end

    test "inventory:add-item defaults guide_frequency to manual" do
      _status, json, = run_cli("inventory:add-item", "--name", "Salt")
      assert_equal "manual", json.dig("data", "inventory_item", "guide_frequency")
    end

    test "inventory:add-item without a name is a usage error" do
      status, _json, err = run_cli("inventory:add-item")
      assert_equal 1, status
      assert_equal "usage_error", err.dig("error", "type")
    end

    test "schema lists the authoring commands as mutating" do
      _status, json, = run_cli("schema")
      by_name = json.dig("data", "commands").index_by { |c| c["command"] }
      assert_equal true, by_name["tasks:create"]["mutates"]
      assert_equal true, by_name["tasks:create-list"]["mutates"]
      assert_equal true, by_name["inventory:add-item"]["mutates"]
      assert_equal false, by_name["tasks:lists"]["mutates"]
    end
  end
end
