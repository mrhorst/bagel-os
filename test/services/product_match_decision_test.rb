require "test_helper"

class ProductMatchDecisionTest < ActiveSupport::TestCase
  setup do
    @supplier = Supplier.create!(name: "Primary Supplier")
    @product = @supplier.products.create!(canonical_name: "Half and Half")
    @suggested = @supplier.products.create!(canonical_name: "American Cheese Yellow")
  end

  test "allows auto link only for product matches at the confidence threshold" do
    decision = Purchasing::ProductMatchDecision.new(
      product: @product,
      confidence: BigDecimal("0.9"),
      basis: "exact raw receipt alias",
      source: "order_guide"
    )

    assert decision.auto_link?
    assert decision.confident?
    assert_not decision.review_required?
    assert_equal @product, decision.linked_product
  end

  test "requires review for low confidence product matches" do
    decision = Purchasing::ProductMatchDecision.new(
      product: @product,
      confidence: BigDecimal("0.89"),
      basis: "almost but not enough",
      source: "order_guide"
    )

    assert_not decision.auto_link?
    assert decision.review_required?
    assert_nil decision.linked_product
  end

  test "keeps suggestions separate from auto links" do
    decision = Purchasing::ProductMatchDecision.new(
      suggested_product: @suggested,
      confidence: BigDecimal("0.4"),
      basis: "low-confidence token similarity",
      source: "receipt"
    )

    assert decision.suggestion?
    assert decision.review_required?
    assert_not decision.auto_link?
    assert_equal @suggested, decision.suggested_product
  end
end
