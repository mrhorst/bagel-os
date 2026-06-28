class NormalizationReviewsController < ApplicationController
  require_module_access :normalization_reviews

  def index
    pending = NormalizationReview.includes(:product, receipt_line_item: [ :receipt, :import_batch ]).pending.recent
    @pending_count = pending.count
    @view = params[:view] == "list" ? "list" : "focus"

    if @view == "list"
      @reviews = pending
    else
      skipped = session_skipped_ids
      @current_review = pending.where.not(id: skipped).first || pending.first
      @position = @current_review ? (pending.pluck(:id).index(@current_review.id).to_i + 1) : 0
    end

    @products = Product.order(:canonical_name)
    @categories = ProductCategory.ordered
  end

  def assign_product
    review = NormalizationReview.find(params[:id])
    product = Product.find_by(id: params[:product_id])

    unless product
      redirect_back fallback_location: normalization_reviews_path, alert: "Choose a product to assign first."
      return
    end

    review_workflow.assign_existing_product(review: review, product: product)
    clear_skipped(review.id)

    redirect_to normalization_reviews_path, notice: "Line item assigned to #{product.canonical_name}."
  end

  def create_product
    review = NormalizationReview.find(params[:id])
    product = review_workflow.create_product_from_review(
      review: review,
      canonical_name: params[:canonical_name],
      product_category_id: params[:product_category_id]
    )
    clear_skipped(review.id)

    redirect_to normalization_reviews_path, notice: "Created #{product.canonical_name}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: normalization_reviews_path,
      alert: "Couldn't create product: #{e.record.errors.full_messages.to_sentence}. Try assigning to an existing product instead."
  end

  def resolve
    review = NormalizationReview.find(params[:id])
    updated = review_workflow.update_review_status(review: review, status: params[:review_status], notes: params[:resolution_notes])
    clear_skipped(review.id)
    redirect_back fallback_location: normalization_reviews_path, notice: "Review marked #{updated.status}."
  end

  def skip
    review = NormalizationReview.find(params[:id])
    session[:skipped_review_ids] = (session_skipped_ids + [ review.id ]).last(200)
    redirect_to normalization_reviews_path, notice: "Skipped for now — it'll come back around at the end of the queue."
  end

  private

  def session_skipped_ids
    Array(session[:skipped_review_ids])
  end

  def clear_skipped(id)
    return unless session[:skipped_review_ids].present?
    session[:skipped_review_ids] = session_skipped_ids - [ id ]
  end

  def review_workflow
    @review_workflow ||= Purchasing::NormalizationReviewWorkflow.new
  end
end
