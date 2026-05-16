module Purchasing
  class PriceSpikeFlagger
    MIN_OBSERVATIONS = 3
    SPIKE_MULTIPLIER = BigDecimal("1.25")

    def flag_all!
      Product.find_each do |product|
        flag_product!(product)
      end
    end

    def flag_product!(product)
      product.price_observations.chronological.group_by(&:price_spike_series_key).each_value do |observations|
        observations.each_with_index do |observation, index|
          previous = observations[[ 0, index - 5 ].max...index]
          previous_prices = previous.filter_map(&:price_spike_value)
          value = observation.price_spike_value

          if previous_prices.size >= MIN_OBSERVATIONS && value.present?
            average = previous_prices.sum / previous_prices.size
            spike = average.positive? && value.to_d > (average * SPIKE_MULTIPLIER)
            percent = average.positive? ? (((value.to_d - average) / average) * 100).round(2) : nil
            observation.update!(possible_price_spike: spike, percent_above_recent_average: spike ? percent : nil)
          else
            observation.update!(possible_price_spike: false, percent_above_recent_average: nil)
          end
        end
      end
    end
  end
end
