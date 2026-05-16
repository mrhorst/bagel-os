class NormalizationReviewsController < ApplicationController
  def index
    @reviews = NormalizationReview.includes(:product, receipt_line_item: [ :receipt, :import_batch ]).pending.recent
    @products = Product.order(:canonical_name)
    @categories = ProductCategory.ordered
  end

  def assign_product
    review = NormalizationReview.find(params[:id])
    product = Product.find(params[:product_id])
    line_item = review.receipt_line_item

    line_item.update!(product: product, needs_review: false)
    product.product_aliases.find_or_create_by!(raw_name: line_item.raw_name, raw_sku: line_item.raw_sku) do |alias_record|
      alias_record.confidence_score = 1.0
      alias_record.approved = true
    end
    Purchasing::PriceObservationBuilder.new.create_for!(line_item)
    review.update!(product: product, status: "resolved", resolution_notes: "Assigned to existing product.")

    redirect_to normalization_reviews_path, notice: "Line item assigned to #{product.canonical_name}."
  end

  def create_product
    review = NormalizationReview.find(params[:id])
    line_item = review.receipt_line_item
    interpretation = Purchasing::ProductNameInterpreter.new.interpret(line_item.raw_name)
    canonical_name = params[:canonical_name].presence || interpretation.canonical_name

    product = line_item.supplier.products.create!(
      canonical_name: canonical_name,
      supplier_sku: interpretation.family_group? ? nil : line_item.raw_sku,
      product_category_id: params[:product_category_id],
      purchase_unit: line_item.raw_case_quantity.to_d.positive? ? "case" : "unit",
      package_size: line_item.parsed_package_size,
      unit_of_measure: line_item.parsed_unit_of_measure,
      standard_unit: line_item.raw_data.dig("parsed_unit", "standard_unit"),
      notes: Purchasing::ProductNameInterpreter.new.notes_for(
        canonical_name: canonical_name,
        raw_names: [ line_item.raw_name ],
        confidence_score: interpretation.confidence_score,
        basis: interpretation.basis
      ),
      needs_review: false
    )
    product.product_aliases.create!(raw_name: line_item.raw_name, raw_sku: line_item.raw_sku, confidence_score: 1.0, approved: true)
    line_item.update!(product: product, needs_review: false)
    Purchasing::PriceObservationBuilder.new.create_for!(line_item)
    review.update!(product: product, status: "resolved", resolution_notes: "Created product from review screen.")

    redirect_to normalization_reviews_path, notice: "Created #{product.canonical_name}."
  end

  def resolve
    review = NormalizationReview.find(params[:id])
    review.update!(status: params[:review_status].presence_in(NormalizationReview::STATUSES) || "resolved", resolution_notes: params[:resolution_notes])
    redirect_to normalization_reviews_path, notice: "Review updated."
  end
end
