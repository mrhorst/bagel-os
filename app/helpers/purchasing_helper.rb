module PurchasingHelper
  def money(value)
    return "n/a" if value.blank?

    number_to_currency(value)
  end

  # Money for a data-table cell where a missing value means "unknown" (e.g. a
  # product with no recorded price), NOT a real zero. Renders a muted em-dash so
  # absent values recede and the eye lands on actual figures — and so "unknown"
  # reads differently from a known $0.00. Presentation-only.
  def money_cell(value)
    return tag.span("—", class: "cell-empty", title: "No data yet") if value.blank?

    money(value)
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

  # Status chip for an import batch. A failed import must not read the same as a
  # successful one, so the badge carries the status's meaning through colour
  # (the sanctioned semantic badge classes), not a neutral grey for everything.
  # pending/skipped stay neutral — neither success nor error.
  def import_status_badge(batch)
    variant = case batch.status
    when "imported" then "badge-ok"
    when "failed"   then "badge-danger"
    end
    tag.span(batch.status.humanize, class: [ "badge", variant ].compact.join(" "))
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
