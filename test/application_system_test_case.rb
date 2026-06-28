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
    # Some sandboxes (e.g. Claude Code on the web) ship a browser that isn't on
    # the default Chrome search path. Point Selenium at it via env when set;
    # unset, this is a no-op and Selenium resolves the browser as usual.
    if (chrome_binary = ENV["SYSTEM_TEST_CHROME_BINARY"]).present?
      options.binary = chrome_binary
    end
    # Chrome's password manager / autofill intermittently swallows the keystrokes
    # typed into the email + autocomplete="current-password" fields, leaving them
    # blank and making the sign-in system tests flaky (~50% on a 4-test file).
    # Turn the whole thing off for tests so fill_in is deterministic.
    options.add_argument("--disable-features=AutofillServerCommunication,PasswordLeakDetection")
    options.add_preference("credentials_enable_service", false)
    options.add_preference("profile.password_manager_enabled", false)
    options.add_preference("autofill.profile_enabled", false)
  end

  # Headless Chrome intermittently drops the keystrokes Capybara sends to a
  # field — `fill_in` "succeeds" but the input ends up blank, which is what made
  # the sign-in/sign-out system tests flaky (~50%). Retrying the keypresses
  # doesn't help (the field rejects them in that state), so if real typing
  # doesn't stick, set the value directly and fire the same events a keypress
  # would, leaving the form behaving normally for Turbo/validation.
  #
  # Only fields whose value should equal `with` are forced; auto-formatting
  # inputs (value legitimately differs) just keep the typed value.
  def fill_in(locator, with:, **options)
    super
    field = find(:fillable_field, locator, **options)
    return field if field.value == with.to_s

    page.execute_script(<<~JS, field, with.to_s)
      const el = arguments[0], value = arguments[1];
      el.focus();
      el.value = value;
      el.dispatchEvent(new Event("input", { bubbles: true }));
      el.dispatchEvent(new Event("change", { bubbles: true }));
    JS
    field
  end

  # Sign in through the real login form (auth is cookie-based, so there's no
  # shortcut — the browser has to submit the form like a user would).
  def sign_in_as(user, password: "password")
    visit new_session_url
    fill_in "Email", with: user.email_address
    fill_in "Password", with: password
    click_on "Sign in"
    # Chrome occasionally drops the click; if the post-login signal hasn't shown
    # up, the submit was lost — re-submit the form directly.
    resubmit "Sign in" unless has_selector?("a[aria-label='Account']", wait: 3)
    # Block until login actually completes. The account link is only rendered
    # for a signed-in user, so it's a reliable post-login signal (the primary
    # nav element exists even when logged out, so it can't be used here).
    assert_selector "a[aria-label='Account']"
  end

  # Headless Chrome occasionally drops a click, so a submit button press can
  # silently no-op. Submit the named button's form directly — used as a fallback
  # once we've confirmed the click didn't take effect, so it can't double-submit.
  def resubmit(button_label)
    page.execute_script(<<~JS, button_label)
      const label = arguments[0];
      const btn = Array.from(document.querySelectorAll("button, input[type=submit]"))
        .find((b) => (b.value || b.textContent || "").trim() === label);
      if (btn && btn.form) btn.form.requestSubmit(btn);
    JS
  end
end
