require "test_helper"

module PhotoAssets
  class AiReviewJobTest < ActiveJob::TestCase
    class ReviewerSentinel
      def review!(*)
        raise "the AI reviewer must not run for this photo"
      end
    end

    test "does nothing when the reviewer is not configured" do
      asset = create_asset
      AiReviewJob.perform_now(asset.id)
      assert_equal "unreviewed", asset.reload.status
    end

    test "skips photos a human already reviewed" do
      asset = create_asset
      asset.update!(status: "approved", reviewed_via: "manual", reviewed_at: Time.current)

      stub_singleton(AiReviewer, :configured?, ->(*) { true }) do
        stub_singleton(AiReviewer, :new, ->(*) { ReviewerSentinel.new }) do
          AiReviewJob.perform_now(asset.id)
        end
      end

      assert_equal "approved", asset.reload.status
    end

    test "uploading a photo enqueues an AI review when configured" do
      stub_singleton(AiReviewer, :configured?, ->(*) { true }) do
        assert_enqueued_with(job: AiReviewJob) { create_asset }
      end
    end

    test "uploading a photo does not enqueue a review when unconfigured" do
      assert_no_enqueued_jobs(only: AiReviewJob) { create_asset }
    end

    private

    def stub_singleton(mod, name, replacement)
      original = mod.method(name)
      mod.define_singleton_method(name, replacement)
      yield
    ensure
      mod.define_singleton_method(name, original)
    end

    def create_asset
      PhotoAsset.new.tap do |asset|
        asset.photo.attach(
          io: file_fixture("photo_asset_sample.png").open,
          filename: "sample.png",
          content_type: "image/png"
        )
        asset.save!
      end
    end
  end
end
