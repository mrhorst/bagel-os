require "test_helper"

# Static check on the compiled CSS to enforce two rules that prevent the
# "phantom horizontal scroll on mobile" bug:
#
#   1. The base form-control width rule must exclude radio and checkbox.
#      Otherwise a hidden absolutely-positioned radio (segmented controls,
#      custom checkboxes) inherits width: 100%, resolves its containing
#      block to the viewport, and drags the layout wider than device-width.
#
#   2. Any component that positions a child absolutely must itself be
#      positioned. Today that means .radio.radio-segmented declares
#      position: relative explicitly. New components that follow the same
#      pattern should be added to KNOWN_ABSOLUTE_PARENTS below.
#
# Catching these at lint time beats hunting the bug after a release.
class MobileViewportSafetyTest < ActiveSupport::TestCase
  CSS_PATH = Rails.root.join("app/assets/tailwind/application.css")

  # Components that host an absolutely-positioned child and therefore must
  # be position: relative (or any non-static value). If you intentionally
  # want an absolute child to escape, document the exception by *not*
  # adding the parent here.
  KNOWN_ABSOLUTE_PARENTS = %w[
    .radio.radio-segmented
    .tasks-date-pager-label
    .module-overflow
    .log-book-overflow-header
    .mobile-tab
    .task-checkbox
  ].freeze

  test "base input width rule excludes radio and checkbox" do
    css = File.read(CSS_PATH)
    selector = css[/input[^{]*select[^{]*textarea\s*\{[^}]*width:\s*100%/m]
    refute_nil selector, "could not locate the base form-control width rule"
    assert_includes selector, "[type=\"checkbox\"]", "base width rule must exclude type=\"checkbox\""
    assert_includes selector, "[type=\"radio\"]", "base width rule must exclude type=\"radio\""
  end

  test "components that host absolutely-positioned children declare positioning" do
    css = File.read(CSS_PATH)

    blocks = css.scan(/([^{}]+)\{([^}]*)\}/)
    KNOWN_ABSOLUTE_PARENTS.each do |parent|
      escaped = Regexp.escape(parent)
      # Match the parent as a *whole* selector in the comma-separated list,
      # so .task-checkbox doesn't accidentally match .task-checkbox-undo.
      selector_pattern = /(?:^|,)\s*#{escaped}\s*(?:,|$|:)/
      matching_blocks = blocks.select { |selectors, _body| selectors =~ selector_pattern }
      assert matching_blocks.any?, "expected to find a rule block for #{parent}"

      has_positioning = matching_blocks.any? do |_selectors, body|
        body.match?(/position:\s*(relative|absolute|fixed|sticky)/)
      end

      assert has_positioning,
        "#{parent} hosts an absolutely-positioned child but no rule block for it sets position: relative (or absolute/fixed/sticky). The child will escape its intended container and resolve its containing block to the viewport."
    end
  end

  test "task wizard time input is constrained on mobile" do
    css = File.read(CSS_PATH)
    mobile_css = css[/@media \(max-width: 640px\).*?\z/m]
    refute_nil mobile_css, "could not locate the mobile stylesheet block"

    selector = ".task-wizard-panel input[type='time']"
    blocks = mobile_css.scan(/([^{}]+)\{([^}]*)\}/)
      .select { |selectors, _body| selectors.include?(selector) }
    refute_empty blocks, "expected #{selector} to have an explicit mobile containment rule"

    combined_body = blocks.map(&:last).join("\n")
    assert_match(/max-width:\s*100%/, combined_body)
    assert_match(/width:\s*100%/, combined_body)
  end

  test "non-production env banner reserves its height instead of overlaying chrome" do
    css = File.read(CSS_PATH)

    # The ribbon must be sticky, not a fixed overlay — fixed would cover the
    # sidebar brand and the mobile header instead of reserving space for them.
    banner = css[/\.env-banner\s*\{[^}]*\}/m]
    refute_nil banner, "could not locate the .env-banner rule"
    assert_match(/position:\s*sticky/, banner,
      ".env-banner must be sticky so it reserves height in flow rather than overlaying top chrome")

    # The top-pinned chrome must be offset by the banner height while it's on
    # the page, keyed off a --env-banner-h measure.
    offsets = css.scan(/body:has\(\.env-banner\)[^{]*\{([^}]*)\}/m).map(&:first).join("\n")
    refute_empty offsets, "expected body:has(.env-banner) rules to offset top-pinned chrome for the banner"
    assert_match(/--env-banner-h/, offsets,
      "expected the env-banner offsets to key off a --env-banner-h measure")
  end
end
