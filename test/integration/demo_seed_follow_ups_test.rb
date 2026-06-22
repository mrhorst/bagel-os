require "test_helper"

# The qa:flows "follow-ups" journey (Shift → Follow-ups → open an item → back)
# drills from the Follow-ups index into a detail page by clicking the first
# follow-up card. That only works if the demo seed leaves at least one OPEN
# follow-up for the index to list (the index defaults to the "open" scope). If
# the seed ever stops producing one, the harness flow would silently end early
# at the index instead of exercising the detail → back affordance — so guard it.
class DemoSeedFollowUpsTest < ActionDispatch::IntegrationTest
  test "demo seed leaves open follow-ups for the Follow-ups journey to drill into" do
    with_demo_seed do
      assert FollowUp.open.any?,
        "expected the demo seed to create at least one open follow-up to click into"
    end
  end

  test "seeded follow-ups render as cards on the index a person can tap" do
    with_demo_seed do
      get follow_ups_path
      assert_response :success
      assert_select "a.follow-up-card", { minimum: 1 },
        "Follow-ups index should list the seeded open follow-ups as tappable cards"
    end
  end

  private

  # Run the demo branch of db/seeds.rb (gated behind SEED_DEMO_DATA), the same
  # way the qa:flows harness primes its data, and restore the flag afterward.
  def with_demo_seed
    previous = ENV["SEED_DEMO_DATA"]
    ENV["SEED_DEMO_DATA"] = "true"
    Rails.application.load_seed
    yield
  ensure
    ENV["SEED_DEMO_DATA"] = previous
  end
end
