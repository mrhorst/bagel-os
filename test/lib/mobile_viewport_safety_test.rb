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
end
