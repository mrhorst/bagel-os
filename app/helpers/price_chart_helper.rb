module PriceChartHelper
  CHART_MODES = {
    "standard_unit_price" => "Comparable unit price",
    "package_price" => "Presentation price",
    "line_total" => "Total spend",
    "quantity" => "Quantity purchased"
  }.freeze
  CHART_COLORS = %w[#d04f2f #175f73 #6e4c00 #1e5b35 #6b4bb8 #9b2c2c #2f6f4e #7a4f01].freeze

  def price_history_svg(observations, mode:)
    points = observations.filter_map do |observation|
      value = observation.chart_value(mode)
      next if value.blank?

      [ observation, value.to_d ]
    end

    return tag.div("Not enough data for this chart mode yet.", class: "empty-state") if points.empty?

    width = 920
    height = 320
    padding = 44
    series = points.group_by { |observation, _value| observation.chart_series_key(mode) }
    series_labels = series.transform_values { |values| values.first.first.chart_series_label(mode) }
    min_value, max_value = points.map(&:last).minmax
    min_time, max_time = points.map { |observation, _| observation.observed_at.to_i }.minmax
    value_range = [ max_value - min_value, BigDecimal("1") ].max
    time_range = [ max_time - min_time, 1 ].max

    coordinates = points.index_with do |observation, value|
      x = padding + ((observation.observed_at.to_i - min_time).to_f / time_range * (width - (padding * 2)))
      y = height - padding - ((value - min_value).to_f / value_range.to_f * (height - (padding * 2)))
      [ value, x.round(2), y.round(2) ]
    end

    chart = tag.svg(viewBox: "0 0 #{width} #{height}", class: "price-chart", role: "img", aria: { label: CHART_MODES.fetch(mode, "Price history") }) do
      chart_parts = [
        tag.line(x1: padding, y1: height - padding, x2: width - padding, y2: height - padding, class: "chart-axis"),
        tag.line(x1: padding, y1: padding, x2: padding, y2: height - padding, class: "chart-axis"),
        tag.text(format_chart_value(max_value, mode), x: 8, y: padding + 4, class: "chart-label"),
        tag.text(format_chart_value(min_value, mode), x: 8, y: height - padding, class: "chart-label")
      ]

      series.each_with_index do |(_key, series_points), index|
        color = CHART_COLORS[index % CHART_COLORS.size]
        polyline = series_points.map do |point|
          _value, x, y = coordinates.fetch(point)
          "#{x},#{y}"
        end.join(" ")

        chart_parts << tag.polyline(points: polyline, class: "chart-line", style: "stroke: #{color}") if series_points.size > 1
        chart_parts << safe_join(series_points.map do |point|
          observation, _raw_value = point
          value, x, y = coordinates.fetch(point)
          chart_dot(observation, value, x, y, mode, color, series_labels.fetch(observation.chart_series_key(mode)))
        end)
      end

      safe_join(chart_parts)
    end

    safe_join([ chart, chart_legend(series_labels.values) ])
  end

  private

  def chart_dot(observation, value, x, y, mode, color, series_label)
    title = [
      "Date: #{observation.observed_at.to_date}",
      "Raw product: #{observation.receipt_line_item.raw_name}",
      "Presentation: #{observation.presentation_label.presence || 'n/a'}",
      "Quantity: #{compact_decimal(observation.quantity)}",
      "Comparable quantity: #{compact_decimal(observation.standard_quantity)} #{observation.standard_unit}",
      "Package size: #{compact_decimal(observation.package_size)} #{observation.unit_of_measure}",
      "Line total: #{money(observation.line_total)}",
      "Package price: #{money(observation.package_price)}",
      "Series: #{series_label}",
      "Calculated unit price: #{format_chart_value(value, mode)}",
      "Source: #{observation.source_filename}"
    ].join("\n")

    tag.circle(cx: x, cy: y, r: 5, class: observation.possible_price_spike? ? "chart-dot chart-dot-warning" : "chart-dot", style: "fill: #{color}") do
      tag.title(title)
    end
  end

  def chart_legend(labels)
    unique_labels = labels.uniq
    visible_labels = unique_labels.first(8)
    hidden_count = unique_labels.size - visible_labels.size

    tag.div(class: "chart-legend") do
      safe_join([
        *visible_labels.each_with_index.map do |label, index|
          tag.span do
            safe_join([
              tag.i(style: "background: #{CHART_COLORS[index % CHART_COLORS.size]}"),
              label
            ])
          end
        end,
        (tag.span("+ #{hidden_count} more") if hidden_count.positive?)
      ].compact)
    end
  end

  def format_chart_value(value, mode)
    return "n/a" if value.blank?

    mode == "quantity" ? compact_decimal(value) : money(value)
  end
end
