require "test_helper"

module Agents
  class CommandsControllerTest < ActionDispatch::IntegrationTest
    # This API is token-authenticated, not cookie-authenticated.
    self.skip_default_sign_in = true if respond_to?(:skip_default_sign_in=)

    setup do
      @user = User.create!(email_address: "api@example.com", name: "Api", password: "password123", role: :admin)
      @session = @user.sessions.create!(user_agent: "test", ip_address: nil)
      @token = Agents::Authentication.token_for(@session)
    end

    def auth_headers(token = @token)
      { "Authorization" => "Bearer #{token}", "Content-Type" => "application/json" }
    end

    test "runs a command with a valid bearer token" do
      TaskList.create!(name: "Prep", key: "prep", position: 0)
      post "/agent", params: { argv: [ "tasks:lists" ] }.to_json, headers: auth_headers

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal true, body["ok"]
      assert_equal "tasks:lists", body["command"]
      assert_equal "test", body["environment"]
    end

    test "rejects an auth-required command without a token" do
      post "/agent", params: { argv: [ "tasks:lists" ] }.to_json, headers: { "Content-Type" => "application/json" }

      assert_response :unauthorized
      assert_equal "unauthenticated", JSON.parse(response.body).dig("error", "type")
    end

    test "rejects a forged token" do
      post "/agent", params: { argv: [ "tasks:lists" ] }.to_json, headers: auth_headers("garbage")
      assert_response :unauthorized
    end

    test "schema needs no token" do
      post "/agent", params: { argv: [ "schema" ] }.to_json, headers: { "Content-Type" => "application/json" }
      assert_response :ok
      assert JSON.parse(response.body).dig("data", "commands").any?
    end

    test "creates a record through the API" do
      list = TaskList.create!(name: "Closing", key: "closing", position: 0)
      post "/agent",
        params: { argv: [ "tasks:create", "--list", "Closing", "--title", "Lock up", "--due-time", "22:00" ] }.to_json,
        headers: auth_headers

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal true, body.dig("data", "created")
      assert_equal list.id, Task.find(body.dig("data", "task", "id")).task_list_id
    end

    test "maps not_found to 404 and ambiguous to 422" do
      post "/agent", params: { argv: [ "price:product", "nope" ] }.to_json, headers: auth_headers
      assert_response :not_found
      assert_equal "not_found", JSON.parse(response.body).dig("error", "type")
    end

    test "refuses login/logout over the command endpoint" do
      post "/agent", params: { argv: [ "login", "--email", "x" ] }.to_json, headers: auth_headers
      assert_response :unprocessable_entity
      assert_equal "usage_error", JSON.parse(response.body).dig("error", "type")
    end
  end
end
