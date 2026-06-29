module Agents
  module Commands
    # Open normalization reviews — the parsing/matching/unit decisions waiting on
    # a human. The queue an agent should surface rather than guess at.
    class ReviewsPending < Command
      command "reviews:pending"
      summary "Pending normalization reviews awaiting a human decision"
      usage(
        "Options:",
        "  --limit N   Cap the number of reviews returned (default 50)"
      )
      param :limit, type: "integer", desc: "Cap the number of reviews returned (default 50)"

      def call
        limit = options.integer("limit", 50)

        scope = NormalizationReview.pending
          .recent
          .includes(:product, receipt_line_item: :receipt)
        reviews, truncated = fetch_capped(scope, limit)

        {
          reviews: reviews.map { |review| review_json(review) }
        }.merge(page_meta(returned: reviews.size, limit: limit, truncated: truncated))
      end

      private

      def review_json(review)
        line_item = review.receipt_line_item
        {
          id: review.id,
          issue_type: review.issue_type,
          description: review.description,
          product_id: review.product_id,
          product: review.product&.canonical_name,
          raw_name: line_item&.raw_name,
          created_at: iso(review.created_at)
        }
      end
    end
  end
end
