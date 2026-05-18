module PurchasingHelper
  def money(value)
    return "n/a" if value.blank?

    number_to_currency(value)
  end

  def compact_decimal(value)
    return "n/a" if value.blank?

    value.to_d.round(4).to_s("F").sub(/\.?0+$/, "")
  end

  def review_badge(record)
    if record.needs_review?
      tag.span("Needs review", class: "badge badge-warning")
    else
      tag.span("Reviewed", class: "badge badge-ok")
    end
  end

  def tracking_mode_label(membership)
    membership.order_only? ? "Order only" : "Counted"
  end

  def recommendation_status_badge(row)
    label =
      case row.status
      when "buy_now"
        "Buy now"
      when "not_counted"
        "Not counted"
      when "setup_needed"
        "Setup needed"
      when "order_only"
        "Order only"
      else
        "OK"
      end

    badge_class =
      case row.status
      when "buy_now", "setup_needed"
        "badge-warning"
      when "ok"
        "badge-ok"
      else
        nil
      end

    tag.span(label, class: [ "badge", badge_class ].compact)
  end

  def percent_change(first_value, latest_value)
    return "n/a" if first_value.blank? || latest_value.blank? || first_value.to_d.zero?

    change = ((latest_value.to_d - first_value.to_d) / first_value.to_d) * 100
    "#{change.round(1)}%"
  end
end
