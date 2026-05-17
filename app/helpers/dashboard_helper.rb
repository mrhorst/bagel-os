module DashboardHelper
  DASHBOARD_BLOCK_SPANS = {
    "half" => "dashboard-block-span-half",
    "third" => "dashboard-block-span-third",
    "two_thirds" => "dashboard-block-span-two-thirds",
    "full" => "dashboard-block-span-full"
  }.freeze

  def dashboard_block_class(span: "half", priority: nil)
    [
      "dashboard-block",
      DASHBOARD_BLOCK_SPANS.fetch(span.to_s, DASHBOARD_BLOCK_SPANS.fetch("half")),
      ("dashboard-block-#{priority}" if priority.present?)
    ].compact.join(" ")
  end

  def dashboard_status_tone(count)
    count.to_i.positive? ? "warning" : "ok"
  end

  def dashboard_count(value)
    number_with_delimiter(value.to_i)
  end
end
