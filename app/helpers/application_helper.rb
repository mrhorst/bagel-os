module ApplicationHelper
  def app_branding
    @app_branding ||= AppBranding.current
  end

  def current_user
    Current.user
  end

  def user_display_name(user)
    user.name.presence || user.email_address
  end

  def mobile_screen_title
    return content_for(:mobile_title) if content_for?(:mobile_title)
    return content_for(:title) if content_for?(:title)
    matched = app_nav_items.find { |item| active_nav_item?(item) }
    matched&.dig(:label) || app_branding.short_name
  end

  def mobile_fab_button(path, label:, method: nil)
    options = { class: "mobile-fab", aria: { label: label } }
    options[:data] = { turbo_method: method } if method
    link_to path, options do
      content_tag(:span, "+", class: "mobile-fab-icon", aria: { hidden: true })
    end
  end

  def app_nav_items
    all_nav_items.select { |item| nav_item_visible?(item) }
  end

  def all_nav_items
    [
      { label: "Dashboard", path: root_path, match: :root, icon: "chart" },
      { label: "Inventory", path: inventory_path, controller: "inventory", module: "inventory", icon: "boxes" },
      { label: "Tasks", path: tasks_root_path, controller: "dashboard", module: "tasks", icon: "check" },
      { label: "Order Guides", path: order_guides_path, controller: "order_guides", module: "order_guides", icon: "clipboard" },
      { label: "Imports", path: import_batches_path, controller: "import_batches", module: "import_batches", icon: "upload" },
      { label: "Products", path: products_path, controller: "products", module: "products", icon: "package" },
      { label: "Review", path: normalization_reviews_path, controller: "normalization_reviews", module: "normalization_reviews", icon: "alert" },
      { label: "Reports", path: reports_path, controller: "reports", module: "reports", icon: "report" }
    ]
  end

  def nav_item_visible?(item)
    return true if item[:module].blank?
    Current.user&.can_access?(item[:module])
  end

  def active_nav_item?(item)
    if item[:module].present?
      controller_path.start_with?("#{item[:module]}/")
    elsif item[:match] == :root
      current_page?(item[:path])
    else
      controller_name == item[:controller]
    end
  end

  def nav_icon(name)
    paths = {
      "chart" => tag.path(d: "M4 19V5m8 14V9m8 10V3", "stroke-linecap": "round"),
      "boxes" => tag.path(d: "M4 7l8-4 8 4-8 4-8-4Zm0 6l8 4 8-4M4 17l8 4 8-4", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "check" => tag.path(d: "m5 12 4 4L19 6M5 20h14", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "clipboard" => tag.path(d: "M9 4h6m-7 3h8m-8 5h8m-8 4h5M7 4h10a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z", "stroke-linecap": "round"),
      "upload" => tag.path(d: "M12 16V4m0 0 4 4m-4-4-4 4M4 16v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "package" => tag.path(d: "M4 7.5 12 3l8 4.5v9L12 21l-8-4.5v-9Zm8 4.5 8-4.5M12 12 4 7.5m8 4.5v9", "stroke-linejoin": "round"),
      "alert" => tag.path(d: "M12 8v5m0 4h.01M10.3 4.6 3.5 17.2A2 2 0 0 0 5.2 20h13.6a2 2 0 0 0 1.7-2.8L13.7 4.6a2 2 0 0 0-3.4 0Z", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "report" => tag.path(d: "M7 3h7l5 5v13H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Zm7 0v5h5M8 17h8M8 13h8", "stroke-linecap": "round", "stroke-linejoin": "round")
    }

    tag.svg(
      paths.fetch(name),
      class: "nav-icon",
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      "stroke-width": "1.8",
      aria: { hidden: true }
    )
  end
end
