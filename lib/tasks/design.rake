# Design screenshot harness.
#
# Drives the REAL app through a headless Chrome (the same Selenium stack the
# system tests use) and saves a PNG of every primary screen at both a desktop
# and a mobile viewport. It exists so the design-watcher routine — and any human
# doing a visual pass — can SEE the current UI without clicking through 35 pages
# by hand.
#
#   bin/rails design:screenshots                 # all screens, both viewports
#   SCREENS=dashboard,inventory bin/rails design:screenshots
#   VIEWPORTS=mobile bin/rails design:screenshots
#   OUT=tmp/design-screenshots bin/rails design:screenshots
#
# Output lands in tmp/design-screenshots/<slug>-<viewport>.png (gitignored).
#
# This deliberately leans on Capybara's in-process rack server (Capybara.app =
# Rails.application) so there's no separate `rails server` to manage — the task
# is self-contained. It seeds demo data and ensures a sign-in user exists, so a
# fresh checkout with an empty dev DB still produces meaningful screens.
namespace :design do
  # Primary, ID-free screens. Each renders without needing a specific record, so
  # the list stays stable as data changes. {slug, path, label}.
  SCREENS = [
    { slug: "dashboard",            path: "/",                          label: "Dashboard / home" },
    { slug: "hub-shift",            path: "/shift",                     label: "Shift hub" },
    { slug: "hub-stock",            path: "/stock",                     label: "Stock hub" },
    { slug: "hub-buying",           path: "/buying",                    label: "Buying hub" },
    { slug: "hub-more",             path: "/more",                      label: "More hub" },
    { slug: "log-book",             path: "/log-book",                  label: "Log book" },
    { slug: "log-book-settings",    path: "/log-book/settings",         label: "Log book settings" },
    { slug: "log-book-history",     path: "/log-book/history",          label: "Log book history" },
    { slug: "log-book-sections",    path: "/log-book/sections",         label: "Log book sections" },
    { slug: "follow-ups",           path: "/follow-ups",                label: "Follow-ups" },
    { slug: "tasks",                path: "/tasks",                     label: "Tasks dashboard" },
    { slug: "tasks-history",        path: "/tasks/history",             label: "Tasks history" },
    { slug: "tasks-manage",         path: "/tasks/manage",              label: "Tasks manage hub" },
    { slug: "tasks-manage-lists",   path: "/tasks/manage/lists",        label: "Manage task lists" },
    { slug: "tasks-manage-tasks",   path: "/tasks/manage/tasks",        label: "Manage tasks" },
    { slug: "tasks-setup",          path: "/tasks/manage/tasks/setup",  label: "Tasks setup" },
    { slug: "inventory",            path: "/inventory",                 label: "Inventory overview" },
    { slug: "inventory-items",      path: "/inventory/items",           label: "Inventory items" },
    { slug: "inventory-shopping",   path: "/inventory/shopping-list",   label: "Shopping list" },
    { slug: "inventory-counts",     path: "/inventory/counts",          label: "Inventory counts" },
    { slug: "inventory-count-new",  path: "/inventory/counts/new",      label: "New inventory count" },
    { slug: "order-guides",         path: "/order_guides",              label: "Order guides" },
    { slug: "products",             path: "/products",                  label: "Products" },
    { slug: "import-batches",       path: "/import_batches",            label: "Import batches" },
    { slug: "import-batch-new",     path: "/import_batches/new",        label: "New import batch" },
    { slug: "normalization",        path: "/normalization_reviews",     label: "Normalization reviews" },
    { slug: "reports",              path: "/reports",                   label: "Reports" },
    { slug: "marketing-photos",     path: "/marketing/photos",          label: "Marketing photos" },
    { slug: "marketing-photo-new",  path: "/marketing/photos/new",      label: "Upload photo" },
    { slug: "marketing-collections", path: "/marketing/collections",    label: "Marketing collections" },
    { slug: "account",              path: "/account",                   label: "Account settings" },
    { slug: "admin-users",          path: "/admin/users",               label: "Admin: users" },
    { slug: "admin-tags",           path: "/admin/tags",                label: "Admin: tags" }
  ].freeze

  # 390x844 = the standard iPhone 14/15/16 logical viewport — the width most
  # users actually have, so the watcher reviews that rather than an older Plus.
  VIEWPORTS = {
    "desktop" => [ 1280, 1400 ],
    "mobile"  => [ 390, 844 ]
  }.freeze

  # The app is adaptive (light + dark via `@media (prefers-color-scheme)`), and
  # dark is the live default on most phones — so both schemes get captured. We
  # force the scheme deterministically through Chrome's emulated media (CDP)
  # rather than hoping the headless default matches.
  SCHEMES = %w[light dark].freeze

  SIGN_IN_EMAIL    = "design@example.com"
  SIGN_IN_PASSWORD = "password"

  desc "Screenshot every primary screen at desktop + mobile widths (headless Chrome)"
  task screenshots: :environment do
    require "capybara"
    require "capybara/selenium/driver"
    require "selenium-webdriver"

    out_dir = ENV.fetch("OUT", "tmp/design-screenshots")
    FileUtils.mkdir_p(out_dir)

    wanted_slugs = ENV["SCREENS"]&.split(",")&.map(&:strip)
    screens = wanted_slugs ? SCREENS.select { |s| wanted_slugs.include?(s[:slug]) } : SCREENS

    wanted_vps = ENV["VIEWPORTS"]&.split(",")&.map(&:strip)
    viewports = wanted_vps ? VIEWPORTS.slice(*wanted_vps) : VIEWPORTS

    wanted_schemes = ENV["SCHEMES"]&.split(",")&.map(&:strip)
    schemes = wanted_schemes || SCHEMES

    ensure_demo_data!
    user = ensure_sign_in_user!

    Capybara.app = Rails.application
    Capybara.server = :puma, { Silent: true }
    Capybara.default_max_wait_time = 5

    Capybara.register_driver :design_chrome do |app|
      options = Selenium::WebDriver::Chrome::Options.new
      options.add_argument("--headless=new")
      options.add_argument("--no-sandbox")
      options.add_argument("--disable-dev-shm-usage")
      options.add_argument("--disable-gpu")
      options.add_argument("--hide-scrollbars")
      options.add_argument("--force-color-profile=srgb")
      options.add_argument("--disable-features=AutofillServerCommunication,PasswordLeakDetection")
      Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
    end

    session = Capybara::Session.new(:design_chrome, Rails.application)
    sign_in(session, user)

    manifest = []
    schemes.each do |scheme|
      emulate_color_scheme(session, scheme)
      viewports.each do |vp_name, (w, h)|
        session.current_window.resize_to(w, h)
        screens.each do |screen|
          path = File.join(out_dir, "#{screen[:slug]}-#{vp_name}-#{scheme}.png")
          begin
            session.visit(screen[:path])
            # Let Turbo finish swapping + fonts settle before the capture.
            session.has_css?("body", wait: 3)
            sleep 0.4
            session.save_screenshot(path)
            manifest << { slug: screen[:slug], viewport: vp_name, scheme: scheme, label: screen[:label], path: path, ok: true }
            puts "  ✓ #{screen[:slug]} (#{vp_name}, #{scheme}) → #{path}"
          rescue => e
            manifest << { slug: screen[:slug], viewport: vp_name, scheme: scheme, label: screen[:label], path: path, ok: false, error: e.message }
            warn "  ✗ #{screen[:slug]} (#{vp_name}, #{scheme}): #{e.class}: #{e.message}"
          end
        end
      end
    end

    session.driver.quit
    File.write(File.join(out_dir, "manifest.json"), JSON.pretty_generate(manifest))
    ok = manifest.count { |m| m[:ok] }
    puts "\nSaved #{ok}/#{manifest.size} screenshots to #{out_dir} (manifest.json written)."
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  # Force `prefers-color-scheme` through Chrome DevTools' emulated media so the
  # capture is deterministic instead of inheriting the headless host default.
  def emulate_color_scheme(session, scheme)
    session.driver.browser.execute_cdp(
      "Emulation.setEmulatedMedia",
      media: "screen",
      features: [ { name: "prefers-color-scheme", value: scheme } ]
    )
  end

  def sign_in(session, user)
    session.visit("/session/new")
    session.fill_in("Email", with: user.email_address)
    session.fill_in("Password", with: SIGN_IN_PASSWORD)
    session.click_on("Sign in")
    unless session.has_css?("a[aria-label='Account']", wait: 5)
      raise "Sign-in failed — login form did not produce an authenticated session"
    end
  end

  # An admin so every module is visible in the nav and no screen is hidden
  # behind a permission gate (admins pass every `can_access?` check). Not an
  # owner — there's a single-owner unique constraint and ownership only gates a
  # transfer UI we don't need here. Idempotent.
  def ensure_sign_in_user!
    user = User.find_or_initialize_by(email_address: SIGN_IN_EMAIL)
    user.password = SIGN_IN_PASSWORD
    user.role = :admin
    user.owner = false
    user.save!
    user
  end

  def ensure_demo_data!
    Rails.application.load_seed
  rescue => e
    warn "  ! seed step skipped: #{e.class}: #{e.message}"
  end
end
