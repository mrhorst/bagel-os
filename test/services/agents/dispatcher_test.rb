require "test_helper"

module Agents
  class DispatcherTest < ActiveSupport::TestCase
    setup do
      @user = User.create!(email_address: "disp@example.com", name: "Disp", password: "password123", role: :admin)
      @session = @user.sessions.create!(user_agent: "test", ip_address: nil)
    end

    teardown { Current.reset }

    test "the envelope carries environment and generated_at" do
      result = Dispatcher.new(session: @session).call([ "whoami" ])
      assert result.ok?
      assert_equal "test", result.payload[:environment]
      assert result.payload[:generated_at].present?
    end

    test "an auth-required command without a session is unauthenticated" do
      result = Dispatcher.new(session: nil).call([ "tasks:lists" ])
      assert_not result.ok?
      assert_equal "unauthenticated", result.error_type
    end

    test "production blocks a mutation without --yes" do
      result = Dispatcher.new(session: @session, production: true).call([ "tasks:create-list", "--name", "Closing" ])
      assert_not result.ok?
      assert_equal "confirmation_required", result.error_type
      assert_not TaskList.exists?(name: "Closing")
    end

    test "production allows a mutation with --yes" do
      result = Dispatcher.new(session: @session, production: true).call([ "tasks:create-list", "--name", "Closing", "--yes" ])
      assert result.ok?, result.payload.inspect
      assert TaskList.exists?(name: "Closing")
    end

    test "production still allows reads without --yes" do
      result = Dispatcher.new(session: @session, production: true).call([ "tasks:lists" ])
      assert result.ok?
    end

    test "the API context refuses local-only commands" do
      result = Dispatcher.new(session: @session, context: :api).call([ "login", "--email", "x" ])
      assert_not result.ok?
      assert_equal "usage_error", result.error_type
    end

    test "an unknown command is reported with a hint" do
      result = Dispatcher.new(session: @session).call([ "frobnicate" ])
      assert_equal "unknown_command", result.error_type
      assert result.payload.dig(:error, :hint).present?
    end

    test "mutations record the authenticated user in the audit trail" do
      TaskList.create!(name: "Audit List", key: "audit-list", position: 0)
      result = Dispatcher.new(session: @session).call(
        [ "tasks:create", "--list", "Audit List", "--title", "Audited task", "--due-time", "09:00" ]
      )
      assert result.ok?, result.payload.inspect

      version = Task.find_by!(title: "Audited task").versions.last
      assert_equal @user.id.to_s, version.whodunnit
    end

    test "command --help returns usage without running or requiring auth" do
      result = Dispatcher.new(session: nil).call([ "tasks:create-list", "--help" ])
      assert result.ok?
      assert_equal "tasks:create-list", result.payload.dig(:data, :command)
      assert result.payload.dig(:data, :usage).any?
      assert_not TaskList.exists?(name: "Audited-help")
    end
  end
end
