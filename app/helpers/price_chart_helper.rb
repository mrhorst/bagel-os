module PriceChartHelper
  CHART_MODES = {
    "standard_unit_price" => "Comparable unit price",
    "inner_unit_price" => "Inner unit price",
    "package_price" => "Presentation price",
    "line_total" => "Total spend",
    "quantity" => "Pricing quantity"
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
    height = 360
    padding_left = 56
    padding_right = 24
    padding_top = 44
    padding_bottom = 68
    plot_width = width - padding_left - padding_right
    plot_height = height - padding_top - padding_bottom
    series = points.group_by { |observation, _value| observation.chart_series_key(mode) }
    series_labels = series.transform_values { |values| values.first.first.chart_series_label(mode) }
    min_value, max_value = points.map(&:last).minmax
    axis_min, axis_max = chart_value_bounds(min_value, max_value)
    min_time, max_time = points.map { |observation, _| observation.observed_at.to_i }.minmax
    value_range = axis_max - axis_min
    time_range = max_time - min_time

    coordinates = points.index_with do |observation, value|
      x = x_coordinate(
        observed_time: observation.observed_at.to_i,
        min_time: min_time,
        time_range: time_range,
        plot_left: padding_left,
        plot_width: plot_width
      )
      y = (padding_top + plot_height) - ((value - axis_min).to_f / value_range.to_f * plot_height)
      [ value, x.round(2), y.round(2) ]
    end

    chart = tag.svg(viewBox: "0 0 #{width} #{height}", class: "price-chart", role: "img", aria: { label: CHART_MODES.fetch(mode, "Price history") }) do
      chart_parts = [
        tag.line(x1: padding_left, y1: padding_top + plot_height, x2: width - padding_right, y2: padding_top + plot_height, class: "chart-axis"),
        tag.line(x1: padding_left, y1: padding_top, x2: padding_left, y2: padding_top + plot_height, class: "chart-axis"),
        tag.text(format_chart_value(axis_max, mode), x: 8, y: padding_top + 4, class: "chart-label"),
        tag.text(format_chart_value(axis_min, mode), x: 8, y: padding_top + plot_height, class: "chart-label"),
        tag.text("Purchase date", x: padding_left + (plot_width / 2), y: height - 12, class: "chart-label chart-axis-title", "text-anchor": "middle")
      ]

      chart_parts.concat(date_axis_parts(points, coordinates, baseline: padding_top + plot_height))

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
          safe_join([
            chart_value_label(observation, value, x, y, mode, width: width, padding_top: padding_top, padding_right: padding_right),
            chart_dot(observation, value, x, y, mode, color, series_labels.fetch(observation.chart_series_key(mode)))
          ])
        end)
      end

      safe_join(chart_parts)
    end

    safe_join([ chart, chart_legend(series_labels.values) ])
  end

  private

  def x_coordinate(observed_time:, min_time:, time_range:, plot_left:, plot_width:)
    return plot_left + (plot_width / 2.0) if time_range.zero?

    plot_left + ((observed_time - min_time).to_f / time_range * plot_width)
  end

  def chart_value_bounds(min_value, max_value)
    range = max_value - min_value
    return [ min_value, max_value ] if range.positive?

    padding = [ max_value.to_d.abs * BigDecimal("0.1"), BigDecimal("1") ].max
    axis_min = min_value - padding
    axis_max = max_value + padding
    axis_min = BigDecimal("0") if min_value.to_d >= 0 && axis_min.negative?

    [ axis_min, axis_max ]
  end

  def date_axis_parts(points, coordinates, baseline:)
    date_ticks(points, coordinates).flat_map do |date, x|
      [
        tag.line(x1: x, y1: baseline, x2: x, y2: baseline + 6, class: "chart-axis chart-date-tick"),
        tag.text(date.iso8601, x: x, y: baseline + 24, class: "chart-label chart-date-label", "text-anchor": "middle")
      ]
    end
  end

  def date_ticks(points, coordinates)
    first_points_by_date = points.each_with_object({}) do |point, grouped|
      observation, = point
      grouped[observation.observed_at.to_date] ||= point
    end
    sorted_dates = first_points_by_date.keys.sort
    visible_dates = evenly_spaced(sorted_dates, limit: 6)

    visible_dates.map do |date|
      _value, x, = coordinates.fetch(first_points_by_date.fetch(date))
      [ date, x ]
    end
  end

  def evenly_spaced(values, limit:)
    return values if values.size <= limit

    last_index = values.size - 1
    (0...limit).map { |index| values[(index * last_index.to_f / (limit - 1)).round] }.uniq
  end

  def chart_dot(observation, value, x, y, mode, color, series_label)
    title = [
      "Date: #{observation.observed_at.to_date}",
      "Raw product: #{observation.receipt_line_item.raw_name}",
      "Presentation: #{observation.presentation_label.presence || 'n/a'}",
      "Purchase kind: #{observation.purchase_kind.presence || observation.receipt_line_item.purchase_kind}",
      "Unit Qty: #{compact_decimal(observation.unit_quantity)}",
      "Case Qty: #{compact_decimal(observation.case_quantity)}",
      "Pricing Qty: #{compact_decimal(observation.quantity)}",
      "Inner quantity: #{compact_decimal(observation.inner_quantity)} #{observation.inner_unit_label}",
      "Inner unit price: #{money(observation.inner_unit_price)}",
      "Comparable quantity: #{compact_decimal(observation.standard_quantity)} #{observation.standard_unit}",
      "Package size: #{compact_decimal(observation.package_size)} #{observation.unit_of_measure}",
      "Line total: #{money(observation.line_total)}",
      "Package price: #{money(observation.package_price)}",
      "Series: #{series_label}",
      "Calculated unit price: #{format_chart_value(value, mode)}",
      "Source: #{observation.source_filename}"
    ].join("\n")

    tag.circle(
      cx: x,
      cy: y,
      r: 5,
      class: observation.possible_price_spike? ? "chart-dot chart-dot-warning" : "chart-dot",
      style: "fill: #{color}",
      data: {
        purchase_date: observation.observed_at.to_date.iso8601,
        receipt_number: observation.receipt_line_item.receipt.receipt_number
      }
    ) do
      tag.title(title)
    end
  end

  def chart_value_label(observation, value, x, y, mode, width:, padding_top:, padding_right:)
    label_x = x.to_f.clamp(66, width - padding_right - 6)
    label_y = [ y.to_f - 12, padding_top + 14 ].max
    anchor = x.to_f > width - padding_right - 80 ? "end" : "middle"

    tag.text(
      format_point_value(value, mode, observation),
      x: label_x.round(2),
      y: label_y.round(2),
      class: "chart-label chart-point-label",
      "text-anchor": anchor
    )
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

  def format_point_value(value, mode, observation)
    formatted = format_chart_value(value, mode)

    case mode
    when "standard_unit_price"
      observation.standard_unit.present? ? "#{formatted}/#{observation.standard_unit}" : formatted
    when "inner_unit_price"
      observation.inner_unit_label.present? ? "#{formatted}/#{observation.inner_unit_label}" : formatted
    else
      formatted
    end
  end
end
