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

  # Headline like "Today, Wed May 20" — orients the user in time instead of
  # the prior shouty "Operations dashboard" label.
  def dashboard_today_headline(date = Date.current)
    "Today, #{date.strftime('%a %b %-d')}"
  end

  # Time-of-day greeting, e.g. "Good morning, Sam". Uses the app time zone
  # (Time.current) and the user's first name when we have one.
  def dashboard_greeting(user = current_user, time = Time.current)
    part_of_day =
      case time.hour
      when 5...12  then "Good morning"
      when 12...17 then "Good afternoon"
      else              "Good evening"
      end

    first_name = user&.name.to_s.split.first
    first_name.present? ? "#{part_of_day}, #{first_name}" : part_of_day
  end

  # Counts the number of distinct work areas that have anything to do.
  def dashboard_attention_buckets(*counts)
    counts.count { |c| c.to_i.positive? }
  end
end
