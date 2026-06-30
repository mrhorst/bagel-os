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
  end
end
