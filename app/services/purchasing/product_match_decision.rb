module Purchasing
  class ProductMatchDecision
    CONFIDENT_MATCH_THRESHOLD = BigDecimal("0.9")

    attr_reader :product, :suggested_product, :confidence, :basis, :source

    def initialize(product: nil, suggested_product: nil, confidence:, basis:, source: nil)
      @product = product
      @suggested_product = suggested_product
      @confidence = confidence.to_d
      @basis = basis
      @source = source
    end

    def auto_link?
      product.present? && confidence >= CONFIDENT_MATCH_THRESHOLD
    end
    alias_method :confident?, :auto_link?

    def suggestion?
      product.blank? && suggested_product.present?
    end

    def review_required?
      !auto_link?
    end

    def linked_product
      auto_link? ? product : nil
    end
  end
end
