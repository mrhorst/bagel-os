require "test_helper"
require "tmpdir"
require "fileutils"

module Agents
  # The auth gate and the login/logout/whoami lifecycle. Unlike the other CLI
  # tests, this one drives real credentials through a temp config dir rather
  # than minting a token directly.
  class AuthenticationTest < ActiveSupport::TestCase
    include AgentCliTestHelper

    setup do
      @config_dir = Dir.mktmpdir
      ENV["BAGEL_OS_CONFIG_DIR"] = @config_dir
      ENV.delete("BAGEL_AGENT_TOKEN")
      @user = User.create!(email_address: "owner@example.com", name: "Owner", password: "password123", role: :admin)
    end

    teardown do
      ENV.delete("BAGEL_OS_CONFIG_DIR")
      ENV.delete("BAGEL_AGENT_TOKEN")
      FileUtils.remove_entry(@config_dir) if @config_dir && File.exist?(@config_dir)
    end

    test "domain commands require authentication" do
      status, _json, err = run_cli("tasks:lists")
      assert_equal 1, status
      assert_equal "unauthenticated", err.dig("error", "type")
    end

    test "schema and help do not require authentication" do
      status, json, = run_cli("schema")
      assert_equal 0, status
      assert json.dig("data", "commands").any?
    end

    test "login then a domain command succeeds" do
      status, json, = run_cli("login", "--email", "owner@example.com", "--password", "password123")
      assert_equal 0, status
      assert_equal true, json.dig("data", "authenticated")

      status, json, = run_cli("tasks:lists")
      assert_equal 0, status
      assert_equal true, json["ok"]
    end

    test "login persists an owner-only credentials file and no token in output by default" do
      _status, json, = run_cli("login", "--email", "owner@example.com", "--password", "password123")
      path = json.dig("data", "credentials_path")
      assert File.exist?(path)
      assert_equal "600", format("%o", File.stat(path).mode & 0o777)
      assert_nil json.dig("data", "token")
    end

    test "--print-token includes the token for env-based use" do
      _status, json, = run_cli("login", "--email", "owner@example.com", "--password", "password123", "--print-token")
      assert json.dig("data", "token").present?
    end

    test "login with a bad password is rejected" do
      status, _json, err = run_cli("login", "--email", "owner@example.com", "--password", "nope")
      assert_equal 1, status
      assert_equal "unauthenticated", err.dig("error", "type")
      assert_not File.exist?(File.join(@config_dir, "credentials.json"))
    end

    test "whoami reports the user after login and is unauthenticated before" do
      _status, json, = run_cli("whoami")
      assert_equal false, json.dig("data", "authenticated")

      run_cli("login", "--email", "owner@example.com", "--password", "password123")
      _status, json, = run_cli("whoami")
      assert_equal true, json.dig("data", "authenticated")
      assert_equal "owner@example.com", json.dig("data", "user", "email")
    end

    test "logout revokes the session and clears the token" do
      run_cli("login", "--email", "owner@example.com", "--password", "password123")
      assert_equal 1, @user.sessions.count

      status, json, = run_cli("logout")
      assert_equal 0, status
      assert_equal true, json.dig("data", "session_revoked")
      assert_equal 0, @user.sessions.count

      status, _json, err = run_cli("tasks:lists")
      assert_equal 1, status
      assert_equal "unauthenticated", err.dig("error", "type")
    end

    test "logout revokes both the env-token session and the file-token session" do
      run_cli("login", "--email", "owner@example.com", "--password", "password123")
      env_session = @user.sessions.create!(user_agent: "env", ip_address: nil)
      ENV["BAGEL_AGENT_TOKEN"] = Authentication.token_for(env_session)
      assert_equal 2, @user.sessions.count

      _status, json, = run_cli("logout")
      assert_equal 2, json.dig("data", "sessions_revoked")
      assert_equal 0, @user.sessions.count
    end

    test "an expired token no longer authenticates" do
      session = @user.sessions.create!(user_agent: "t", ip_address: nil)
      ENV["BAGEL_AGENT_TOKEN"] = Authentication.verifier.generate(
        { "sid" => session.id }, purpose: Authentication::VERIFIER_PURPOSE, expires_in: 1.second
      )
      travel 2.seconds do
        status, _json, err = run_cli("tasks:lists")
        assert_equal 1, status
        assert_equal "unauthenticated", err.dig("error", "type")
      end
    end

    test "a revoked session's token no longer authenticates" do
      session = @user.sessions.create!(user_agent: "t", ip_address: nil)
      ENV["BAGEL_AGENT_TOKEN"] = Authentication.token_for(session)
      assert_equal 0, run_cli("tasks:lists").first

      session.destroy
      status, _json, err = run_cli("tasks:lists")
      assert_equal 1, status
      assert_equal "unauthenticated", err.dig("error", "type")
    end

    test "a forged token does not authenticate" do
      ENV["BAGEL_AGENT_TOKEN"] = "not-a-real-token"
      status, _json, err = run_cli("tasks:lists")
      assert_equal 1, status
      assert_equal "unauthenticated", err.dig("error", "type")
    end
  end
end
