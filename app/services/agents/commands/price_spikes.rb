module Agents
  module Commands
    # Recent price observations flagged as possible spikes (a purchase well
    # above the product's recent average). These are the price-intelligence
    # signals worth a human's attention.
    class PriceSpikes < Command
      command "price:spikes"
      summary "Recent purchases flagged as possible price spikes"
      usage(
        "Options:",
        "  --limit N   Cap the number of spikes returned (default 25)"
      )
      param :limit, type: "integer", desc: "Cap the number of spikes returned (default 25)"

      def call
        limit = options.integer("limit", 25)

        observations = PriceObservation.spikes
          .includes(:product, :supplier)
          .order(observed_at: :desc)
          .limit(limit)

        {
          count: observations.size,
          spikes: observations.map { |observation| spike_json(observation) }
        }
      end

      private

      def spike_json(observation)
        {
          product_id: observation.product_id,
          product: observation.product&.canonical_name,
          supplier: observation.supplier&.name,
          observed_at: iso(observation.observed_at),
          percent_above_recent_average: observation.percent_above_recent_average&.to_s,
          package_price: money(observation.package_price),
          standard_unit_price: money(observation.standard_unit_price),
          standard_unit: observation.standard_unit
        }
      end
    end
  end
end
