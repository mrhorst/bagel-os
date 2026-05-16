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

  def percent_change(first_value, latest_value)
    return "n/a" if first_value.blank? || latest_value.blank? || first_value.to_d.zero?

    change = ((latest_value.to_d - first_value.to_d) / first_value.to_d) * 100
    "#{change.round(1)}%"
  end
end
