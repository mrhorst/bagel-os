require "test_helper"

# These methods read attributes only and never touch the database, so they're
# exercised on unsaved instances — no need to build the product/receipt graph.
class PriceObservationTest < ActiveSupport::TestCase
  test "chart_value selects the column for the requested mode" do
    obs = PriceObservation.new(
      standard_unit_price: 5, inner_unit_price: 2, package_price: 20, line_total: 40, quantity: 3
    )

    assert_equal 5, obs.chart_value("standard_unit_price")
    assert_equal 2, obs.chart_value("inner_unit_price")
    assert_equal 40, obs.chart_value("line_total")
    assert_equal 3, obs.chart_value("quantity")
    assert_equal 20, obs.chart_value("anything-else")
    # package_price mode prefers the comparable standard-unit price when present.
    assert_equal 5, obs.chart_value("package_price")
    assert_equal 20, PriceObservation.new(package_price: 20).chart_value("package_price")
  end

  test "chart_series_key namespaces by mode and falls back" do
    assert_equal "standard_unit:lb", PriceObservation.new(standard_unit: "lb").chart_series_key("standard_unit_price")
    assert_equal "standard_unit:unknown", PriceObservation.new.chart_series_key("standard_unit_price")
    assert_equal "inner_unit:can", PriceObservation.new(inner_unit_label: "can").chart_series_key("inner_unit_price")
    assert_equal "presentation:beans", PriceObservation.new(presentation_key: "beans").chart_series_key("package_price")
  end

  test "chart_unit_key groups comparable observations" do
    assert_equal "standard_unit:lb", PriceObservation.new(standard_unit: "lb").chart_unit_key("standard_unit_price")
    assert_equal "standard_unit:unknown", PriceObservation.new.chart_unit_key("standard_unit_price")
    assert_equal "quantity", PriceObservation.new.chart_unit_key("quantity")
    assert_equal "money", PriceObservation.new.chart_unit_key("line_total")
  end

  test "price_spike_value prefers the most comparable price available" do
    assert_equal 7, PriceObservation.new(standard_unit_price: 7, inner_unit_price: 2, package_price: 9).price_spike_value
    assert_equal 2, PriceObservation.new(inner_unit_price: 2, package_price: 9).price_spike_value
    assert_equal 9, PriceObservation.new(package_price: 9).price_spike_value
  end

  test "presentation_chart_uses_comparable_unit? needs both standard fields" do
    assert PriceObservation.new(standard_unit_price: 4, standard_unit: "lb").presentation_chart_uses_comparable_unit?
    assert_not PriceObservation.new(standard_unit_price: 4).presentation_chart_uses_comparable_unit?
    assert_not PriceObservation.new(standard_unit: "lb").presentation_chart_uses_comparable_unit?
  end
end
