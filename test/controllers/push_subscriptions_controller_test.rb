require "test_helper"

class PushSubscriptionsControllerTest < ActionDispatch::IntegrationTest
  # The default sign-in (users(:one)) is the current user for these requests.
  setup { @user = users(:one) }

  def subscription_params(endpoint: "https://push.example.com/abc")
    { push_subscription: { endpoint: endpoint, p256dh_key: "p256dh", auth_key: "auth" } }
  end

  test "create stores a subscription for the current user" do
    assert_difference -> { @user.push_subscriptions.count }, 1 do
      post push_subscriptions_path, params: subscription_params, as: :json
    end

    assert_response :created
    subscription = @user.push_subscriptions.find_by(endpoint: "https://push.example.com/abc")
    assert_equal "p256dh", subscription.p256dh_key
    assert_equal "auth", subscription.auth_key
  end

  test "create is idempotent for the same endpoint" do
    post push_subscriptions_path, params: subscription_params, as: :json

    assert_no_difference -> { @user.push_subscriptions.count } do
      post push_subscriptions_path,
        params: subscription_params.deep_merge(push_subscription: { auth_key: "rotated" }),
        as: :json
    end

    assert_response :created
    assert_equal "rotated", @user.push_subscriptions.find_by(endpoint: "https://push.example.com/abc").auth_key
  end

  test "destroy removes the subscription by endpoint" do
    @user.push_subscriptions.create!(endpoint: "https://push.example.com/abc", p256dh_key: "p", auth_key: "a")

    assert_difference -> { @user.push_subscriptions.count }, -1 do
      delete push_subscriptions_path, params: { endpoint: "https://push.example.com/abc" }, as: :json
    end

    assert_response :no_content
  end

  test "requires authentication" do
    sign_out

    post push_subscriptions_path, params: subscription_params, as: :json

    assert_redirected_to new_session_path
  end
end
