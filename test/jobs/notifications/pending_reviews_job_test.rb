require "test_helper"

module Notifications
  class PendingReviewsJobTest < ActiveJob::TestCase
    include ActiveSupport::Testing::TimeHelpers
    include PushNotificationTestHelper

    setup do
      @admin = users(:one) # owner/admin → in the :normalization_reviews audience
      @admin.push_subscriptions.create!(
        endpoint: "https://push.example.com/admin", p256dh_key: "p", auth_key: "a"
      )

      @supplier = Supplier.create!(name: "Test Supplier")
      @import_batch = @supplier.import_batches.create!(
        source_filename: "reviews.csv", file_checksum: SecureRandom.hex(12),
        imported_at: Time.current, status: "imported"
      )
      @receipt = @supplier.receipts.create!(
        import_batch: @import_batch, receipt_number: SecureRandom.hex(6),
        purchased_at: Time.zone.local(2026, 5, 1, 8, 30)
      )
    end

    test "notifies and records the dispatch when reviews are pending" do
      2.times { create_pending_review }

      sent = at_nine_am { capture_push_notifications { PendingReviewsJob.perform_now(now: Time.current) } }

      assert_equal 1, sent.size
      assert_equal "2 import lines need review", sent.first[:title]
      assert_equal "/normalization_reviews", sent.first[:url]
      assert_equal "normalization-reviews-pending", sent.first[:tag]
      assert_equal 2, NotificationDispatch.for(PendingReviewsJob::KIND).last_count
    end

    test "uses singular wording for a single pending review" do
      create_pending_review

      sent = at_nine_am { capture_push_notifications { PendingReviewsJob.perform_now(now: Time.current) } }

      assert_equal "1 import line needs review", sent.first[:title]
    end

    test "does not re-notify an unchanged backlog but does notify on growth" do
      2.times { create_pending_review }

      at_nine_am { capture_push_notifications { PendingReviewsJob.perform_now(now: Time.current) } }
      unchanged = at_nine_am { capture_push_notifications { PendingReviewsJob.perform_now(now: Time.current) } }
      assert_empty unchanged

      create_pending_review # backlog grows to 3
      grown = at_nine_am { capture_push_notifications { PendingReviewsJob.perform_now(now: Time.current) } }
      assert_equal "3 import lines need review", grown.first[:title]
    end

    test "stays silent when nothing is pending" do
      sent = at_nine_am { capture_push_notifications { PendingReviewsJob.perform_now(now: Time.current) } }

      assert_empty sent
      assert_equal 0, NotificationDispatch.for(PendingReviewsJob::KIND).last_count
    end

    test "stays silent during quiet hours" do
      2.times { create_pending_review }

      sent = travel_to(Time.zone.local(2026, 6, 19, 2)) do
        capture_push_notifications { PendingReviewsJob.perform_now(now: Time.current) }
      end

      assert_empty sent
    end

    private

    def at_nine_am(&block)
      travel_to(Time.zone.local(2026, 6, 19, 9), &block)
    end

    def create_pending_review
      line_item = @receipt.receipt_line_items.create!(
        supplier: @supplier, import_batch: @import_batch,
        line_number: ReceiptLineItem.count + 1, line_type: "item",
        raw_name: "EGGS XLG #{SecureRandom.hex(3)}", row_checksum: SecureRandom.hex(16)
      )
      line_item.normalization_reviews.create!(
        issue_type: "missing_category", description: "Needs review."
      )
    end
  end
end
