require "test_helper"

module Notifications
  class AudienceTest < ActiveSupport::TestCase
    setup do
      @admin = users(:one)    # owner/admin
      @employee = users(:two) # plain employee
      subscribe(@admin)
      subscribe(@employee)
    end

    test "includes admins regardless of explicit module permission" do
      assert_includes Audience.for_module(:tasks), @admin
    end

    test "includes employees who hold the module permission" do
      @employee.user_module_permissions.create!(module_name: "tasks")
      assert_includes Audience.for_module(:tasks), @employee
    end

    test "excludes employees without the module permission" do
      assert_not_includes Audience.for_module(:tasks), @employee
    end

    test "excludes users without a push subscription even if permitted" do
      @employee.user_module_permissions.create!(module_name: "tasks")
      @employee.push_subscriptions.destroy_all

      assert_not_includes Audience.for_module(:tasks), @employee
    end

    test "returns each user once" do
      @admin.push_subscriptions.create!(endpoint: "https://push.example.com/admin-2", p256dh_key: "p", auth_key: "a")

      assert_equal 1, Audience.for_module(:tasks).where(id: @admin.id).count
    end

    private

    def subscribe(user)
      user.push_subscriptions.create!(
        endpoint: "https://push.example.com/#{user.id}",
        p256dh_key: "p256dh",
        auth_key: "auth"
      )
    end
  end
end
