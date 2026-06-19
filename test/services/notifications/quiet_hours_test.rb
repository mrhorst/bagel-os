require "test_helper"

module Notifications
  class QuietHoursTest < ActiveSupport::TestCase
    test "the overnight window is quiet" do
      [ 22, 23, 0, 3, 5 ].each do |hour|
        assert QuietHours.active?(Time.zone.local(2026, 6, 19, hour)), "expected #{hour}:00 to be quiet"
      end
    end

    test "daytime is not quiet" do
      [ 6, 9, 14, 21 ].each do |hour|
        refute QuietHours.active?(Time.zone.local(2026, 6, 19, hour)), "expected #{hour}:00 to be active"
      end
    end
  end
end
