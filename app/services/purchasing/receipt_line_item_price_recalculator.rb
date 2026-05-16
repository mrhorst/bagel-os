module Purchasing
  class ReceiptLineItemPriceRecalculator
    def initialize(line_normalizer: ReceiptLineNormalizer.new, observation_builder: PriceObservationBuilder.new, review_workflow: NormalizationReviewWorkflow.new)
      @line_normalizer = line_normalizer
      @observation_builder = observation_builder
      @review_workflow = review_workflow
    end

    def recalculate_all!
      stats = { line_items_reviewed: 0, line_items_updated: 0, observations_rebuilt: 0 }

      PriceObservation.delete_all

      ReceiptLineItem.includes(:product, :receipt, :import_batch, :normalization_reviews).find_each do |line_item|
        stats[:line_items_reviewed] += 1
        normalized_line = recalculate_line_item!(line_item, flag_price_spikes: false)
        stats[:line_items_updated] += 1
        stats[:observations_rebuilt] += 1 if normalized_line
      end

      PriceSpikeFlagger.new.flag_all!
      stats.merge(price_observations_total: PriceObservation.count)
    end

    def recalculate_line_item!(line_item, flag_price_spikes: true)
      normalized_line = line_normalizer.normalize(
        line_data: line_data_for(line_item),
        existing_raw_data: line_item.raw_data,
        product: line_item.product
      )

      update_line_item!(line_item, normalized_line)
      sync_unit_reviews!(line_item, normalized_line)
      observation = observation_builder.create_for!(line_item)
      line_item.price_observation&.destroy! unless observation
      PriceSpikeFlagger.new.flag_product!(line_item.product) if flag_price_spikes && line_item.product
      observation
    end

  private

    attr_reader :line_normalizer, :observation_builder, :review_workflow

    def line_data_for(line_item)
      {
        line_number: line_item.line_number,
        line_type: line_item.line_type,
        supplier: line_item.supplier,
        raw_name: line_item.raw_name,
        raw_sku: line_item.raw_sku,
        raw_quantity: line_item.raw_quantity,
        raw_case_quantity: line_item.raw_case_quantity,
        line_total: line_item.line_total,
        raw_data: line_item.raw_data
      }
    end

    def update_line_item!(line_item, normalized_line)
      line_item.update!(normalized_line.normalized_attributes)
    end

    def sync_unit_reviews!(line_item, normalized_line)
      review_workflow.sync_unit_reviews!(
        line_item: line_item,
        intents: normalized_line.review_intents(product: line_item.product)
      )
    end
  end
end
