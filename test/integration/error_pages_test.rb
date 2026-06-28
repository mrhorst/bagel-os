require "test_helper"

# The static HTTP error pages in public/ are what a user actually lands on in
# production (consider_all_requests_local = false) when they hit a missing
# route, a stale link to a deleted record, or a server error. They are branded
# but, before this guard, offered NO way back into the app — a dead end where
# the only escape was the browser's own back button.
#
# Each standard error page must carry an in-content escape link back to the
# app root ("/" → dashboard when signed in, sign-in when not).
class ErrorPagesTest < ActiveSupport::TestCase
  # 406 (unsupported browser) and offline.html are intentionally excluded: the
  # browser can't run the app in the first case, and there's no connection to
  # reach "/" in the second, so an in-app link would be useless there.
  ESCAPABLE_ERROR_PAGES = %w[400.html 404.html 422.html 500.html].freeze

  ESCAPABLE_ERROR_PAGES.each do |page|
    test "#{page} offers a link back into the app" do
      html = File.read(Rails.root.join("public", page))

      assert_includes html, %(href="/"),
        "#{page} has no escape link back to the app root — a user who lands here is stranded"
    end
  end
end
