# Persisted anti-spam state for aggregate, condition-based push notifications.
#
# Recurring jobs that watch a backlog ("N normalization reviews are pending",
# "N price spikes flagged") need to remember what they last told users so they
# don't re-notify an unchanged pile every run. Each `kind` gets exactly one
# row recording the last count we notified about; the job notifies only when
# the current count exceeds it, and ratchets the marker down as work is cleared
# so a future growth re-triggers.
#
#   dispatch = NotificationDispatch.for("normalization_reviews_pending")
#   if dispatch.announce?(current_count)
#     # ... send the push ...
#     dispatch.record!(current_count, at: Time.current)
#   else
#     dispatch.settle!(current_count) # keep the high-water mark honest
#   end
class NotificationDispatch < ApplicationRecord
  validates :kind, presence: true, uniqueness: true
  validates :last_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def self.for(kind)
    find_or_create_by!(kind: kind.to_s)
  end

  # True when the backlog has grown past what we last announced — the only time
  # it's worth pushing again.
  def announce?(count)
    count.positive? && count > last_count
  end

  # Remember that we just notified about `count` items.
  def record!(count, at: Time.current)
    update!(last_count: count, last_sent_at: at)
  end

  # Keep the high-water mark in step with reality without notifying: when the
  # backlog shrinks (work got done) we lower it so the next genuine increase
  # crosses the threshold again.
  def settle!(count)
    update!(last_count: count) if count < last_count
  end
end
