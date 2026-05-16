class PriceObservation < ApplicationRecord
  belongs_to :product
  belongs_to :receipt_line_item
  belongs_to :supplier

  validates :observed_at, :source_filename, presence: true
  validates :receipt_line_item_id, uniqueness: true

  scope :chronological, -> { order(:observed_at, :id) }
  scope :with_standard_unit_price, -> { where.not(standard_unit_price: nil) }
  scope :spikes, -> { where(possible_price_spike: true) }

  def chart_value(mode)
    case mode
    when "standard_unit_price"
      standard_unit_price
    when "line_total"
      line_total
    when "quantity"
      quantity
    else
      package_price
    end
  end

  def chart_series_key(mode)
    if mode == "standard_unit_price"
      "standard_unit:#{standard_unit.presence || 'unknown'}"
    else
      "presentation:#{presentation_key.presence || receipt_line_item_id}"
    end
  end

  def chart_series_label(mode)
    if mode == "standard_unit_price"
      standard_unit.present? ? "Price / #{standard_unit}" : "No comparable unit"
    else
      presentation_label.presence || receipt_line_item.raw_name
    end
  end

  def price_spike_value
    standard_unit_price.presence || package_price
  end

  def price_spike_series_key
    standard_unit_price.present? ? chart_series_key("standard_unit_price") : chart_series_key("package_price")
  end
end
