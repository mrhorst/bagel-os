# Mirrors the browser's PushManager subscription into PushSubscription rows.
#
# The Stimulus controller posts JSON here after the user grants permission, and
# DELETEs (with the endpoint in the body) when they opt out. Authentication is
# the normal session cookie; CSRF is enforced via the X-CSRF-Token header the
# fetch sends from the meta tag.
class PushSubscriptionsController < ApplicationController
  def create
    subscription = Current.user.push_subscriptions.find_or_initialize_by(endpoint: subscription_params[:endpoint])
    subscription.assign_attributes(
      p256dh_key: subscription_params[:p256dh_key],
      auth_key: subscription_params[:auth_key],
      user_agent: request.user_agent
    )

    if subscription.save
      head :created
    else
      render json: { errors: subscription.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def destroy
    Current.user.push_subscriptions.where(endpoint: params.require(:endpoint)).destroy_all
    head :no_content
  end

  private

  def subscription_params
    params.expect(push_subscription: %i[endpoint p256dh_key auth_key])
  end
end
