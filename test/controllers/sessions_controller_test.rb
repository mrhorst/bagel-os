require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  self.skip_default_sign_in = true
  setup { @user = User.take }

  test "new" do
    get new_session_path
    assert_response :success
  end

  test "create with valid credentials" do
    post session_path, params: { email_address: @user.email_address, password: "password" }

    assert_redirected_to root_path
    assert cookies[:session_id]
  end

  test "create with invalid credentials re-renders the form in place with the email preserved" do
    post session_path, params: { email_address: @user.email_address, password: "wrong" }

    assert_response :unprocessable_entity
    assert_nil cookies[:session_id]
    # The user gets feedback and does NOT have to retype their email address.
    assert_select "div.flash-alert", text: "Try another email address or password."
    assert_select "input[name=?][value=?]", "email_address", @user.email_address
  end

  test "destroy" do
    sign_in_as(User.take)

    delete session_path

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
  end
end
