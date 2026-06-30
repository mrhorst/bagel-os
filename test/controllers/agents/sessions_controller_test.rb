require "test_helper"

module Agents
  class SessionsControllerTest < ActionDispatch::IntegrationTest
    self.skip_default_sign_in = true if respond_to?(:skip_default_sign_in=)

    setup do
      @user = User.create!(email_address: "api@example.com", name: "Api", password: "password123", role: :admin)
    end

    test "login returns a usable token" do
      post "/agent/session", params: { email: "api@example.com", password: "password123" }.to_json,
        headers: { "Content-Type" => "application/json" }

      assert_response :ok
      body = JSON.parse(response.body)
      assert_equal true, body["ok"]
      assert body["token"].present?
      assert_equal "api@example.com", body.dig("user", "email")

      # the token authenticates a follow-up command
      post "/agent", params: { argv: [ "whoami" ] }.to_json,
        headers: { "Authorization" => "Bearer #{body['token']}", "Content-Type" => "application/json" }
      assert_equal "api@example.com", JSON.parse(response.body).dig("data", "user", "email")
    end

    test "login with a bad password is unauthorized and creates no session" do
      assert_no_difference -> { Session.count } do
        post "/agent/session", params: { email: "api@example.com", password: "wrong" }.to_json,
          headers: { "Content-Type" => "application/json" }
      end
      assert_response :unauthorized
      assert_equal "unauthenticated", JSON.parse(response.body).dig("error", "type")
    end

    test "logout revokes the session" do
      session = @user.sessions.create!(user_agent: "test", ip_address: nil)
      token = Agents::Authentication.token_for(session)

      assert_difference -> { Session.count }, -1 do
        delete "/agent/session", headers: { "Authorization" => "Bearer #{token}" }
      end
      assert_response :ok
      assert_equal true, JSON.parse(response.body)["logged_out"]
    end
  end
end
