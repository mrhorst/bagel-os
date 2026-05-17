class NormalizationReviewsController < ApplicationController
  def index
    @reviews = NormalizationReview.includes(:product, receipt_line_item: [ :receipt, :import_batch ]).pending.recent
    @products = Product.order(:canonical_name)
    @categories = ProductCategory.ordered
  end

  def assign_product
    review = NormalizationReview.find(params[:id])
    product = Product.find(params[:product_id])

    review_workflow.assign_existing_product(review: review, product: product)

    redirect_to normalization_reviews_path, notice: "Line item assigned to #{product.canonical_name}."
  end

  def create_product
    review = NormalizationReview.find(params[:id])
    product = review_workflow.create_product_from_review(
      review: review,
      canonical_name: params[:canonical_name],
      product_category_id: params[:product_category_id]
    )

    redirect_to normalization_reviews_path, notice: "Created #{product.canonical_name}."
  end

  def resolve
    review = NormalizationReview.find(params[:id])
    review_workflow.update_review_status(review: review, status: params[:review_status], notes: params[:resolution_notes])
    redirect_back fallback_location: normalization_reviews_path, notice: "Review updated."
  end

  private

  def review_workflow
    @review_workflow ||= Purchasing::NormalizationReviewWorkflow.new
  end
end
