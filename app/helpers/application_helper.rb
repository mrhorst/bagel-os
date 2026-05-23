module ApplicationHelper
  # ── Navigation catalog ────────────────────────────────────────────────
  # One source of truth for the bottom-nav hubs and the modules that live
  # inside each. Helpers below derive: the mobile tab bar, hub pages, the
  # auto back-chevron in the mobile header, sidebar items, and the active
  # state for any page. Adding a new module = one entry here.

  HUBS = [
    { key: :shift,  label: "Shift",  icon: "check",     path_helper: :shift_hub_path,  subtitle: "Everything you touch during a shift." },
    { key: :stock,  label: "Stock",  icon: "boxes",     path_helper: :stock_hub_path,  subtitle: "What's on hand and what's on the shelf." },
    { key: :buying, label: "Buying", icon: "clipboard", path_helper: :buying_hub_path, subtitle: "Order guides and what they tell you over time." },
    { key: :more,   label: "More",   icon: "package",   path_helper: :more_hub_path,   subtitle: "Less-frequent tools and your account." }
  ].freeze

  MODULES = [
    { key: :tasks,          label: "Tasks",        hub: :shift,  icon: "check",     path_helper: :tasks_root_path,         controllers: %w[tasks],                                            module_name: "tasks",                description: "Today's prep, cleaning, and recurring checks." },
    { key: :log_book,       label: "Log Book",     hub: :shift,  icon: "book",      path_helper: :log_book_path,           controllers: %w[log_book log_book_history log_book_settings log_book_sections log_book_responses], module_name: "log_book", description: "Daily notes, counts, and follow-ups." },
    { key: :inventory,      label: "Inventory",    hub: :stock,  icon: "boxes",     path_helper: :inventory_path,          controllers: %w[inventory],                                        module_name: "inventory",            description: "Counts, par levels, and shopping list." },
    { key: :products,       label: "Products",     hub: :stock,  icon: "package",   path_helper: :products_path,           controllers: %w[products product_order_guide_memberships],         module_name: "products",             description: "The catalog managers price and order against." },
    { key: :import_batches, label: "Imports",      hub: :stock,  icon: "upload",    path_helper: :import_batches_path,     controllers: %w[import_batches receipt_line_items],                module_name: "import_batches",       description: "Receipts and order guide uploads." },
    { key: :order_guides,   label: "Order Guides", hub: :buying, icon: "clipboard", path_helper: :order_guides_path,       controllers: %w[order_guides order_guide_memberships],             module_name: "order_guides",         description: "Vendor catalogs and what to reorder." },
    { key: :reports,        label: "Reports",      hub: :buying, icon: "report",    path_helper: :reports_path,            controllers: %w[reports],                                          module_name: "reports",              description: "Spend, price changes, and trends." },
    { key: :review,         label: "Review",       hub: :more,   icon: "alert",     path_helper: :normalization_reviews_path, controllers: %w[normalization_reviews],                         module_name: "normalization_reviews", description: "Resolve uncertain receipt and product matches." },
    { key: :users,          label: "Users",        hub: :more,   icon: "users",     path_helper: :admin_users_path,        controllers: %w[admin/users],                                      admin_only: true,                    description: "Team members and what they can access." },
    { key: :account,        label: "Account",      hub: :more,   icon: "users",     path_helper: :account_path,            controllers: %w[accounts passwords sessions],                                                           description: "Your profile, password, and sign out." }
  ].freeze

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
    current_module_def&.dig(:label) || current_hub_def&.dig(:label) || app_branding.short_name
  end

  def mobile_fab_button(path, label:, method: nil)
    options = { class: "mobile-fab", aria: { label: label } }
    options[:data] = { turbo_method: method } if method
    link_to path, options do
      content_tag(:span, "+", class: "mobile-fab-icon", aria: { hidden: true })
    end
  end

  # Sidebar (desktop): list every module the user can see, flat.
  def sidebar_nav_items
    [{ label: "Dashboard", path: root_path, icon: "chart", root: true }] +
      MODULES.select { |m| module_visible?(m) }.map { |m| m.merge(path: send(m[:path_helper])) }
  end

  # Mobile bottom tab bar: Home + the 4 hubs.
  def mobile_tab_items
    [{ key: :home, label: "Home", icon: "chart", path: root_path, root: true }] +
      HUBS.map { |h| h.merge(path: send(h[:path_helper])) }
  end

  def hub_modules(hub_key)
    MODULES.select { |m| m[:hub] == hub_key && module_visible?(m) }
  end

  def hub_def(hub_key)
    HUBS.find { |h| h[:key] == hub_key }
  end

  # The module the user is currently viewing, if any. Used to drive the
  # leading back-chevron and the active tab.
  def current_module_def
    return @__current_module_def if defined?(@__current_module_def)
    cp = controller_path
    @__current_module_def = MODULES.find do |m|
      m[:controllers].any? { |c| cp == c || cp.start_with?("#{c}/") }
    end
  end

  # The hub the user is currently inside — either because the URL is the
  # hub page itself, or because the current module belongs to one.
  def current_hub_def
    return @__current_hub_def if defined?(@__current_hub_def)
    @__current_hub_def =
      if controller_path == "hubs"
        action = action_name.to_sym
        HUBS.find { |h| h[:key] == action }
      elsif current_module_def
        hub_def(current_module_def[:hub])
      end
  end

  def on_module_page?
    current_module_def.present?
  end

  def module_visible?(m)
    return false if m[:admin_only] && !Current.user&.admin?
    return true if m[:module_name].blank?
    Current.user&.can_access?(m[:module_name])
  end

  def active_nav_item?(item)
    if item[:root]
      current_page?(root_path)
    elsif item[:controllers] # module
      cp = controller_path
      item[:controllers].any? { |c| cp == c || cp.start_with?("#{c}/") }
    elsif item[:key] && HUBS.any? { |h| h[:key] == item[:key] } # hub tab
      current_hub_def&.dig(:key) == item[:key]
    end
  end

  def nav_icon(name)
    paths = {
      "chart" => tag.path(d: "M4 19V5m8 14V9m8 10V3", "stroke-linecap": "round"),
      "boxes" => tag.path(d: "M4 7l8-4 8 4-8 4-8-4Zm0 6l8 4 8-4M4 17l8 4 8-4", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "check" => tag.path(d: "m5 12 4 4L19 6M5 20h14", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "gear" => tag.path(d: "M12 8.5a3.5 3.5 0 1 1 0 7 3.5 3.5 0 0 1 0-7Zm0-5v2m0 13v2m8.5-8.5h-2m-13 0h-2m14.5-6.5-1.4 1.4M6.9 17.1l-1.4 1.4m0-13 1.4 1.4m10.2 10.2 1.4 1.4", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "book" => tag.path(d: "M5 4.5A2.5 2.5 0 0 1 7.5 2H19v17H7.5A2.5 2.5 0 0 0 5 21.5v-17Zm0 0v17M8 6h7M8 10h7", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "clipboard" => tag.path(d: "M9 4h6m-7 3h8m-8 5h8m-8 4h5M7 4h10a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2Z", "stroke-linecap": "round"),
      "upload" => tag.path(d: "M12 16V4m0 0 4 4m-4-4-4 4M4 16v3a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-3", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "package" => tag.path(d: "M4 7.5 12 3l8 4.5v9L12 21l-8-4.5v-9Zm8 4.5 8-4.5M12 12 4 7.5m8 4.5v9", "stroke-linejoin": "round"),
      "alert" => tag.path(d: "M12 8v5m0 4h.01M10.3 4.6 3.5 17.2A2 2 0 0 0 5.2 20h13.6a2 2 0 0 0 1.7-2.8L13.7 4.6a2 2 0 0 0-3.4 0Z", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "report" => tag.path(d: "M7 3h7l5 5v13H7a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2Zm7 0v5h5M8 17h8M8 13h8", "stroke-linecap": "round", "stroke-linejoin": "round"),
      "users" => tag.path(d: "M16 11a4 4 0 1 0-8 0 4 4 0 0 0 8 0Zm-12 9a8 8 0 0 1 16 0", "stroke-linecap": "round", "stroke-linejoin": "round")
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
