require "test_helper"

module PhotoAssets
  class AiTaggingJobTest < ActiveJob::TestCase
    class TaggerSentinel
      def tag!(*)
        raise "the AI tagger must not run for this photo"
      end
    end

    test "does nothing when the tagger is not configured" do
      asset = create_asset
      AiTaggingJob.perform_now(asset.id)
      assert_nil asset.reload.ai_tagged_at
    end

    test "skips photos that already had a tagging pass" do
      asset = create_asset
      asset.update_column(:ai_tagged_at, Time.current)

      stub_singleton(AiTagger, :configured?, ->(*) { true }) do
        stub_singleton(AiTagger, :new, ->(*) { TaggerSentinel.new }) do
          assert_nothing_raised { AiTaggingJob.perform_now(asset.id) }
        end
      end

      assert_empty asset.reload.taggings
    end

    test "uploading a photo enqueues an AI tagging pass when configured" do
      stub_singleton(AiTagger, :configured?, ->(*) { true }) do
        assert_enqueued_with(job: AiTaggingJob) { create_asset }
      end
    end

    test "uploading a photo does not enqueue a pass when unconfigured" do
      assert_no_enqueued_jobs(only: AiTaggingJob) { create_asset }
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
