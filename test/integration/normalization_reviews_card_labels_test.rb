require "test_helper"

# Guards the Review Queue card's form controls. The "Assign / Create / Resolve"
# selects and text fields are built with select_tag/text_field_tag, which derive
# their DOM id from the field name. In list view ("Show all") several cards
# render on one page, so without a review-scoped id every card emitted the same
# id="product_id", id="canonical_name", etc. — duplicate, invalid ids — and none
# of the controls carried an associated <label>, leaving them unnamed for
# assistive tech. The names must stay stable so the controllers keep working.
class NormalizationReviewsCardLabelsTest < ActionDispatch::IntegrationTest
  setup do
    @supplier = Supplier.create!(name: "Label Probe Supplier")
    @batch = @supplier.import_batches.create!(
      source_filename: "label-probe.csv",
      file_checksum: "label-probe-#{SecureRandom.hex(8)}",
      imported_at: Time.current,
      status: "imported"
    )
    @receipt = @supplier.receipts.create!(
      import_batch: @batch, receipt_number: "LABEL-PROBE-1", purchased_at: Time.current
    )
    @reviews = 2.times.map do |i|
      line = @receipt.receipt_line_items.create!(
        supplier: @supplier, import_batch: @batch, line_number: i + 1,
        line_type: "item", raw_name: "RAW #{i}", raw_sku: "SKU#{i}",
        row_checksum: SecureRandom.hex(8)
      )
      line.normalization_reviews.create!(issue_type: "missing_category", description: "needs cat #{i}")
    end
  end

  FIELD_NAMES = %w[product_id canonical_name product_category_id review_status resolution_notes].freeze

  test "list view gives every card's controls unique ids and an associated label" do
    get normalization_reviews_path(view: "list")
    assert_response :success

    ids = response.body.scan(/\bid="([^"]+)"/).flatten
    duplicates = ids.tally.select { |_, count| count > 1 }.keys
    assert_empty duplicates, "Expected no duplicate DOM ids, found: #{duplicates.inspect}"

    doc = Nokogiri::HTML(response.body)
    @reviews.each do |review|
      FIELD_NAMES.each do |name|
        scoped_id = "#{name}_#{review.id}"
        control = doc.at_css("##{scoped_id}")
        assert control, "Expected a control with id=#{scoped_id}"
        assert_equal name, control["name"], "Control #{scoped_id} must keep name=#{name} so the controller is unchanged"
        assert doc.at_css("label[for='#{scoped_id}']"), "Expected a <label for='#{scoped_id}'>"
      end
    end
  end

  test "focus view labels its controls too" do
    get normalization_reviews_path
    assert_response :success

    doc = Nokogiri::HTML(response.body)
    # Focus view renders exactly one card; we don't assume which review is
    # current (the queue orders newest-first). Each control must still carry a
    # name-stable, label-associated, review-scoped id.
    FIELD_NAMES.each do |name|
      control = doc.at_css("[name='#{name}']")
      assert control, "Expected a control named #{name} in focus view"
      scoped_id = control["id"]
      assert_match(/\A#{Regexp.escape(name)}_\d+\z/, scoped_id.to_s,
        "Control #{name} should have a review-scoped id, got #{scoped_id.inspect}")
      assert doc.at_css("label[for='#{scoped_id}']"), "Expected a <label for='#{scoped_id}'> in focus view"
    end
  end
end
