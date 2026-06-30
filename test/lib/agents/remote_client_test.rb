require "test_helper"
require "tmpdir"
require "fileutils"

module Agents
  # The remote transport, exercised with an injected fake HTTP transport so no
  # network or server is needed. Verifies it forwards argv with the bearer
  # token, prints the server's envelope, and manages the local token on
  # login/logout.
  class RemoteClientTest < ActiveSupport::TestCase
    # Records calls and replays a queued or fixed response.
    class FakeTransport
      attr_reader :calls

      def initialize(&responder)
        @responder = responder
        @calls = []
      end

      def call(method, url, headers, body)
        @calls << { method: method, url: url, headers: headers, body: body }
        @responder.call(method, url, headers, body)
      end
    end

    setup do
      @config_dir = Dir.mktmpdir
      ENV["BAGEL_OS_CONFIG_DIR"] = @config_dir
      ENV.delete("BAGEL_AGENT_TOKEN")
      ENV.delete("BAGEL_AGENT_PASSWORD")
    end

    teardown do
      ENV.delete("BAGEL_OS_CONFIG_DIR")
      ENV.delete("BAGEL_AGENT_TOKEN")
      FileUtils.remove_entry(@config_dir) if @config_dir && File.exist?(@config_dir)
    end

    def run_remote(argv, transport:)
      out = StringIO.new
      err = StringIO.new
      status = RemoteClient.run(argv, api_url: "https://app.example.test", out: out, err: err, transport: transport)
      [ status, out.string, err.string ]
    end

    test "forwards a command to /agent with the bearer token and prints the envelope" do
      ENV["BAGEL_AGENT_TOKEN"] = "tok-123"
      transport = FakeTransport.new { [ 200, { ok: true, command: "tasks:lists", data: { count: 0 } }.to_json ] }

      status, out, = run_remote([ "tasks:lists" ], transport: transport)

      assert_equal 0, status
      assert_equal true, JSON.parse(out)["ok"]
      call = transport.calls.first
      assert_equal "POST", call[:method]
      assert_equal "https://app.example.test/agent", call[:url]
      assert_equal "Bearer tok-123", call[:headers]["Authorization"]
      assert_equal [ "tasks:lists" ], JSON.parse(call[:body])["argv"]
    end

    test "a failing command prints to stderr and exits 1" do
      transport = FakeTransport.new { [ 401, { ok: false, error: { type: "unauthenticated", message: "no" } }.to_json ] }
      status, out, err = run_remote([ "tasks:lists" ], transport: transport)

      assert_equal 1, status
      assert_empty out
      assert_equal "unauthenticated", JSON.parse(err).dig("error", "type")
    end

    test "login stores the returned token locally" do
      ENV["BAGEL_AGENT_PASSWORD"] = "password123"
      transport = FakeTransport.new do |_m, url, _h, _b|
        assert_equal "https://app.example.test/agent/session", url
        [ 200, { ok: true, environment: "production", token: "fresh-token", user: { email: "you@example.com" } }.to_json ]
      end

      status, out, = run_remote([ "login", "--email", "you@example.com" ], transport: transport)

      assert_equal 0, status
      assert_equal true, JSON.parse(out).dig("data", "authenticated")
      stored = JSON.parse(File.read(File.join(@config_dir, "credentials.json")))
      assert_equal "fresh-token", stored["token"]
    end

    test "login failure does not write a token" do
      ENV["BAGEL_AGENT_PASSWORD"] = "wrong"
      transport = FakeTransport.new { [ 401, { ok: false, error: { type: "unauthenticated", message: "bad" } }.to_json ] }

      status, = run_remote([ "login", "--email", "you@example.com" ], transport: transport)
      assert_equal 1, status
      assert_not File.exist?(File.join(@config_dir, "credentials.json"))
    end

    test "logout calls the endpoint and clears the local token" do
      File.write(File.join(@config_dir, "credentials.json"), { token: "tok", email: "you@example.com" }.to_json)
      transport = FakeTransport.new do |method, url, _h, _b|
        assert_equal "DELETE", method
        assert_equal "https://app.example.test/agent/session", url
        [ 200, { ok: true, session_revoked: true }.to_json ]
      end

      status, out, = run_remote([ "logout" ], transport: transport)
      assert_equal 0, status
      assert_equal true, JSON.parse(out).dig("data", "token_cleared")
      assert_not File.exist?(File.join(@config_dir, "credentials.json"))
    end

    test "a connection failure is reported, not raised" do
      transport = FakeTransport.new { raise RemoteClient::ConnectionError, "Errno::ECONNREFUSED" }
      status, _out, err = run_remote([ "tasks:lists" ], transport: transport)

      assert_equal 1, status
      assert_equal "connection_error", JSON.parse(err).dig("error", "type")
    end
  end
end
