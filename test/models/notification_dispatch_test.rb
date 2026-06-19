require "test_helper"

class NotificationDispatchTest < ActiveSupport::TestCase
  test "for finds or creates exactly one row per kind" do
    first = NotificationDispatch.for("price_spikes")
    second = NotificationDispatch.for("price_spikes")

    assert_equal first.id, second.id
    assert_equal 1, NotificationDispatch.where(kind: "price_spikes").count
    assert_equal 0, first.last_count
  end

  test "announce? is true only when the backlog grows past the last count" do
    dispatch = NotificationDispatch.for("reviews")

    assert dispatch.announce?(3),     "should announce a new backlog"
    refute dispatch.announce?(0),     "should never announce an empty backlog"

    dispatch.record!(3)
    refute dispatch.announce?(3),     "should not re-announce an unchanged backlog"
    refute dispatch.announce?(2),     "should not announce a shrinking backlog"
    assert dispatch.announce?(4),     "should announce further growth"
  end

  test "record! stores the count and the time it was sent" do
    dispatch = NotificationDispatch.for("reviews")
    at = Time.zone.local(2026, 6, 19, 9)

    dispatch.record!(5, at: at)

    assert_equal 5, dispatch.reload.last_count
    assert_equal at, dispatch.last_sent_at
  end

  test "settle! ratchets the high-water mark down as work is cleared" do
    dispatch = NotificationDispatch.for("reviews")
    dispatch.record!(5)

    dispatch.settle!(2)
    assert_equal 2, dispatch.reload.last_count, "should lower the mark when the backlog shrinks"

    dispatch.settle!(4)
    assert_equal 2, dispatch.reload.last_count, "should not raise the mark without announcing"
  end
end
