require "test_helper"

# The qa:flows "imports" journey (Buying → Imports → open a receipt batch →
# back) drills from the Imports index into a batch detail by clicking the first
# batch link. That only works if the demo seed leaves at least one import batch
# for the index to list. If the seed ever stops producing one, the harness flow
# would silently end early at the index instead of exercising the detail → back
# affordance (the cold-load regression guard for the Imports back chevron) — so
# guard the seed here.
class DemoSeedImportTest < ActionDispatch::IntegrationTest
  test "demo seed creates an import batch with receipt lines to drill into" do
    with_demo_seed do
      batch = ImportBatch.find_by(file_checksum: "demo-receipt-0001")
      assert batch, "expected the demo seed to create a demo import batch"
      assert batch.receipt, "expected the seeded batch to have a receipt"
      assert batch.receipt_line_items.any?,
        "expected the seeded batch to have receipt line items so the detail page renders"
    end
  end

  test "seeded import batch renders on the index as a tappable link to its detail" do
    with_demo_seed do
      batch = ImportBatch.find_by(file_checksum: "demo-receipt-0001")
      get import_batches_path
      assert_response :success
      assert_select "a[href=?]", import_batch_path(batch), { minimum: 1 },
        "Imports index should list the seeded batch as a link to its detail page"
    end
  end

  test "re-running the demo seed does not duplicate the import batch" do
    with_demo_seed do
      Rails.application.load_seed
      assert_equal 1, ImportBatch.where(file_checksum: "demo-receipt-0001").count,
        "the demo import seed should be idempotent on file_checksum"
      assert_equal 2, ReceiptLineItem.where(import_batch: ImportBatch.find_by(file_checksum: "demo-receipt-0001")).count,
        "re-seeding should not duplicate the receipt line items"
    end
  end

  private

  # Run the demo branch of db/seeds.rb (gated behind SEED_DEMO_DATA), the same
  # way the qa:flows harness primes its data, and restore the flag afterward.
  def with_demo_seed
    previous = ENV["SEED_DEMO_DATA"]
    ENV["SEED_DEMO_DATA"] = "true"
    Rails.application.load_seed
    yield
  ensure
    ENV["SEED_DEMO_DATA"] = previous
  end
end
