require "test_helper"

# Base class for end-to-end browser tests. These drive a real headless Chrome
# via Selenium, so they exercise the full stack including Turbo and Stimulus —
# the JS behavior that request/integration tests can't reach.
#
# `bin/rails test:system` runs these; the default `bin/rails test` does NOT, so
# they stay out of the fast unit/integration loop and only run when asked.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [1400, 1400] do |options|
    # Required for headless Chrome in sandboxed/CI environments.
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
  end

  # Sign in through the real login form (auth is cookie-based, so there's no
  # shortcut — the browser has to submit the form like a user would).
  def sign_in_as(user, password: "password")
    visit new_session_url
    fill_in "Email", with: user.email_address
    fill_in "Password", with: password
    click_on "Sign in"
    # Block until login actually completes. The account link is only rendered
    # for a signed-in user, so it's a reliable post-login signal (the primary
    # nav element exists even when logged out, so it can't be used here).
    assert_selector "a[aria-label='Account']"
  end
end
