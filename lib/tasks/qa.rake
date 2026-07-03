# QA flow-trace harness.
#
# Drives the REAL app through a headless Chrome (the same Selenium stack the
# system tests and design harness use) and walks a set of core user journeys
# end-to-end, recording the navigation trail at every step. It exists so the
# qa-watcher routine — and any human doing a usability pass — can SEE how the
# app actually behaves when a person clicks through it, not just how a screen
# looks frozen.
#
#   bin/rails qa:flows                 # walk every flow
#   FLOWS=tasks-occurrence bin/rails qa:flows
#   OUT=tmp/qa-flows bin/rails qa:flows
#
# Output lands in tmp/qa-flows/<flow>-<nn>-<phase>.png (gitignored) plus a
# trace.json describing every step.
#
# THE HEADLINE PROBE — back-button divergence. Each sub-page renders a "Back to
# X" affordance whose visible label names a destination (its link href), but the
# `back` Stimulus controller calls history.back() instead whenever same-origin
# history exists — so the place the arrow SAYS it goes and the place it ACTUALLY
# goes can differ. The harness drills into a flow by clicking, then walks back
# out using that affordance and flags every step where the landing URL does not
# match the labeled destination. That divergence is the usability bug a human
# feels as "back didn't take me where I expected."
#
# Like design:screenshots, this leans on Capybara's in-process rack server so
# there's no separate `rails server` to manage, seeds demo data, and ensures a
# sign-in admin exists so a fresh dev DB still produces a meaningful walk.
namespace :qa do
  # Core user journeys. Each drills from an entry path into a sub-page by
  # clicking the first link matching each drill selector in turn (mirroring how
  # a person navigates), so the flow stays stable as specific record IDs change.
  # A drill step that finds no match ends that flow early rather than failing.
  #
  #   slug   — output + filter key
  #   label  — human description
  #   entry  — path the journey starts from (reached via a Turbo visit)
  #   drill  — ordered CSS selectors; first match of each is clicked to go deeper
  FLOWS = [
    { slug: "tasks-list", label: "Tasks → open a task list → back",
      entry: "/tasks", drill: [ "a[href*='/tasks/lists/']" ] },
    { slug: "tasks-manage", label: "Tasks → manage tasks → edit a task → back out",
      entry: "/tasks/manage/tasks", drill: [ "a[href*='/tasks/manage/tasks/'][href$='/edit'], a[href$='/edit']" ] },
    # Log Book settings/sections back-walk. Settings is reached from /log-book via
    # a ⋯ overflow popover — a non-navigating JS toggle, so its link is hidden until
    # tapped — and Sections now lives UNDER settings (no /log-book/sections link on
    # /log-book at all). The old `entry: "/log-book"` drills therefore matched
    # nothing visible, ended the walk on /log-book, and silently back-walked
    # /log-book's own chevron instead of these pages — so the flows reported clean
    # while never touching the affordances they name. Enter at the settings hub (the
    # real parent of both pages) so the back-walk + referrer probe exercise the
    # settings and sections "Back to Log Book" arrows. No popover toggle in the drill
    # — a non-navigating step would log a misleading "clicks did not navigate".
    { slug: "log-book-settings", label: "Log book settings → back to Log Book",
      entry: "/log-book/settings", drill: [] },
    { slug: "log-book-sections", label: "Log book settings → sections → back",
      entry: "/log-book/settings", drill: [ "a[href*='/log-book/sections']" ] },
    { slug: "products-edit", label: "Products → product → edit → back to product → back",
      entry: "/products", drill: [ "a[href*='/products/']:not([href$='/edit'])", "a[href$='/edit']" ] },
    { slug: "order-guides", label: "Order guides → guide → back",
      entry: "/order_guides", drill: [ "a[href*='/order_guides/']" ] },
    { slug: "inventory-count-new", label: "Inventory counts → new count → back",
      entry: "/inventory/counts", drill: [ "a[href*='/inventory/counts/new']" ] },
    { slug: "admin-tags-new", label: "Admin tags → new tag → back",
      entry: "/admin/tags", drill: [ "a[href*='/admin/tags/new']" ] },
    { slug: "follow-ups", label: "Follow-ups → open a flagged item → back",
      entry: "/follow-ups", drill: [ "a[href*='/follow-ups/']" ] },
    { slug: "imports", label: "Imports → open a receipt batch → back",
      entry: "/import_batches", drill: [ "a[href*='/import_batches/']:not([href*='/new'])" ] },
    # Recipes → recipe → edit → back. Exclude the "New recipe" link and the
    # mobile FAB (both /recipes/new) — they render before the recipe table, so a
    # bare a[href*='/recipes/'] would drill into the new-recipe form instead of a
    # real recipe and never reach the show page's "Back to recipes" arrow this
    # flow is named to test. The second drill (a[href$='/edit']) then opens the
    # recipe's Edit page so its "Back to recipe" arrow is exercised too.
    { slug: "recipes-edit", label: "Recipes → recipe → edit → back to recipe → back",
      entry: "/recipes", drill: [ "a[href*='/recipes/']:not([href$='/edit']):not([href$='/new'])", "a[href$='/edit']" ] },
    # Collections (marketing/collections) is the one rotation-adjacent journey
    # with no runtime back-chevron coverage — its pages aren't a nav module, so
    # each renders an in-content "Back to collections" / "Back to library" chevron
    # (a.mobile-header-back) that only an integration test asserts statically.
    # Drive it here so the back-walk + referrer probe exercise that chevron the
    # same way every other sub-page is exercised. Exclude the New/Edit links (they
    # render before the collection cards) so the drill reaches a real collection
    # show page rather than the form.
    { slug: "collections", label: "Collections → open a collection → back",
      entry: "/marketing/collections", drill: [ "a[href*='/marketing/collections/']:not([href$='/new']):not([href$='/edit'])" ] }
  ].freeze

  VIEWPORT = [ 414, 896 ].freeze # mobile — where the back affordance is the primary nav

  SIGN_IN_EMAIL    = "qa@example.com"
  SIGN_IN_PASSWORD = "password"

  # Any element that acts as a "go back" affordance. The controller binding is
  # the reliable signal; the class fallbacks catch plain "Back to X" buttons.
  BACK_SELECTOR = "[data-controller~='back'], a.subpage-back, a.mobile-header-back".freeze

  desc "Walk core user journeys through headless Chrome and trace navigation (incl. back-button divergence)"
  task flows: :environment do
    require "capybara"
    require "capybara/selenium/driver"
    require "selenium-webdriver"

    out_dir = ENV.fetch("OUT", "tmp/qa-flows")
    FileUtils.mkdir_p(out_dir)

    wanted = ENV["FLOWS"]&.split(",")&.map(&:strip)
    flows = wanted ? FLOWS.select { |f| wanted.include?(f[:slug]) } : FLOWS

    ensure_demo_data!
    user = ensure_sign_in_user!

    Capybara.app = Rails.application
    Capybara.server = :puma, { Silent: true }
    Capybara.default_max_wait_time = 5

    Capybara.register_driver :qa_chrome do |app|
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

    session = Capybara::Session.new(:qa_chrome, Rails.application)
    session.current_window.resize_to(*VIEWPORT)
    sign_in(session, user)

    report = []
    flows.each do |flow|
      report << walk_flow(session, flow, out_dir)
    end

    session.driver.quit
    File.write(File.join(out_dir, "trace.json"), JSON.pretty_generate(report))

    walk_div  = report.sum { |f| f[:back_trail].count { |b| b[:diverged] } }
    probe_div = report.count { |f| f.dig(:referrer_probe, :diverged) }
    broken    = report.count { |f| f[:error] }
    puts "\nWalked #{report.size} flow(s) → #{out_dir}/trace.json"
    puts "  back-button divergences (Turbo back-walk):   #{walk_div}"
    puts "  back-button divergences (cold/referrer-set): #{probe_div}  ← the one a user hits via PWA/deep-link/post-submit"
    puts "  flows that errored mid-walk:                 #{broken}"
    puts "Read trace.json for per-step detail; PNGs sit beside it." if report.any?
  end

  # ── flow walk ────────────────────────────────────────────────────────────

  # Drill in by clicking, recording the forward trail, then walk back out using
  # the page's own back affordance and compare each landing against its label.
  def walk_flow(session, flow, out_dir)
    result = { slug: flow[:slug], label: flow[:label], forward_trail: [], back_trail: [], referrer_probe: nil, error: nil }
    shot = ->(phase) { capture(session, out_dir, flow[:slug], result[:forward_trail].size + result[:back_trail].size, phase) }

    session.visit(flow[:entry])
    settle(session)
    result[:forward_trail] << step_snapshot(session, "entry: #{flow[:entry]}")
    shot.call("entry")

    flow[:drill].each_with_index do |selector, i|
      link = session.all(selector, visible: true, wait: 3).first
      unless link
        result[:forward_trail] << { note: "drill step #{i + 1} found no match for #{selector.inspect} — flow ends here", url: session.current_path }
        break
      end
      label = (link.text.strip.tr("\n", " ").squeeze(" ").presence || link[:href])
      href  = link[:href]
      navigated = click_and_navigate(session, link)
      # A real same-origin <a> should move the URL. If two clicks both no-op,
      # it's either the headless dropped-click flake or a genuinely dead link —
      # fall back to visiting the href so the walk still reaches the depth the
      # back-test needs, and record that we had to, so the agent can judge.
      nav_via = navigated ? "click" : "fallback-visit (clicks did not navigate)"
      unless navigated
        session.visit(href) if href.present?
        settle(session)
      end
      snap = step_snapshot(session, "clicked: #{label.truncate(60)}")
      snap[:nav_via] = nav_via
      result[:forward_trail] << snap
      shot.call("drill#{i + 1}")
    end

    deepest = session.current_path

    # Walk back out. From the deepest page, take the primary back affordance,
    # record where its label PROMISED to go vs where it ACTUALLY landed, and
    # repeat until there's no back control left or we stop making progress.
    8.times do
      back = session.all(BACK_SELECTOR, visible: true, wait: 1).first
      break unless back

      from_url     = session.current_path
      labeled_href = back[:href]
      labeled_path = labeled_href.present? ? URI(labeled_href).path : nil
      labeled_aria = back["aria-label"]
      labeled_text = back.text.strip.tr("\n", " ").squeeze(" ")
      referrer     = session.evaluate_script("document.referrer") rescue nil

      navigated   = click_and_navigate(session, back)
      landed_path = session.current_path

      # Classify honestly so the agent isn't fed flake as findings:
      #   no_op    — the affordance was clicked but nothing moved (dead/dropped)
      #   diverged — it moved, but NOT to the destination its label promised
      #   match    — it went exactly where the label said
      outcome =
        if !navigated || landed_path == from_url then "no_op"
        elsif labeled_path.present? && landed_path != labeled_path then "diverged"
        else "match"
        end

      entry = {
        from_url: from_url,
        labeled_destination: labeled_path,
        labeled_aria: labeled_aria,
        labeled_text: labeled_text.truncate(60),
        landed_url: landed_path,
        referrer_present: referrer.to_s.strip.present?,
        outcome: outcome,
        diverged: outcome == "diverged"
      }
      result[:back_trail] << entry
      shot.call("back#{result[:back_trail].size}-#{outcome}")

      break if outcome == "no_op" # nothing moved — stop rather than loop on it
    end

    result[:referrer_probe] = referrer_probe(session, deepest, out_dir, flow[:slug])

    result
  rescue => e
    result[:error] = "#{e.class}: #{e.message}"
    warn "  ✗ #{flow[:slug]}: #{result[:error]}"
    result
  end

  # The headline usability probe. The Turbo back-walk above always "matches"
  # because Turbo navigation leaves document.referrer empty, so the back arrow
  # falls through to its labeled href — the happy path. But a person reaches a
  # page MANY other ways that DO set a same-origin referrer: a PWA cold start, a
  # deep link from a push notification, a bookmark, the redirect after saving a
  # form. In all of those the `back` controller calls history.back() instead of
  # honoring the label — so the arrow that says "Back to X" actually dumps you
  # wherever you came from. This probe reproduces that exact condition: re-enter
  # the deepest page via a full load FROM A DIFFERENT same-origin page, then take
  # the back arrow and see whether it honors its label or strands the user.
  def referrer_probe(session, deep_url, out_dir, slug)
    return { tested: false, reason: "no sub-page reached" } if deep_url.blank? || deep_url == "/"

    session.visit(deep_url)
    settle(session)
    back = session.all(BACK_SELECTOR, visible: true, wait: 1).first
    return { tested: false, reason: "no back affordance on #{deep_url}" } unless back

    labeled_path = back[:href].present? ? URI(back[:href]).path : nil
    labeled_text = back.text.strip.tr("\n", " ").squeeze(" ").truncate(60)
    return { tested: false, reason: "back affordance has no href to compare" } if labeled_path.blank?

    # A neutral predecessor that is NOT where the label points, so a divergence
    # is unambiguous. Dashboard unless that IS the labeled target.
    referrer_from = labeled_path == "/" ? "/stock" : "/"
    session.visit(referrer_from)
    settle(session)
    # Full-load (not Turbo) into the deep page so document.referrer = referrer_from.
    session.execute_script("window.location.href = arguments[0]", deep_url)
    deadline = monotonic + 5
    sleep 0.1 while session.current_path != deep_url && monotonic < deadline
    settle(session)
    referrer = session.evaluate_script("document.referrer").to_s

    click_and_navigate(session, session.all(BACK_SELECTOR, visible: true, wait: 1).first)
    landed = session.current_path
    diverged = landed != labeled_path
    capture(session, out_dir, slug, 99, "referrer-probe-#{diverged ? 'DIVERGED' : 'ok'}")

    {
      tested: true,
      deep_url: deep_url,
      arrived_from: referrer_from,
      referrer_set: referrer.strip.present?,
      labeled_destination: labeled_path,
      labeled_text: labeled_text,
      landed_url: landed,
      diverged: diverged,
      note: diverged ? "Back arrow labeled #{labeled_text.inspect} (→ #{labeled_path}) instead landed on #{landed} — it followed browser history, not its own label." : "Back arrow honored its label."
    }
  rescue => e
    { tested: false, reason: "#{e.class}: #{e.message}" }
  end

  # ── helpers ────────────────────────────────────────────────────────────────

  # Click an element and wait for the URL to actually change. Returns true if
  # navigation happened.
  #
  # The click is dispatched in-page via JS rather than through WebDriver. Headless
  # Chrome drops WebDriver clicks ~half the time (the documented flake the system
  # tests fight), which an earlier version mistook for dead links and flagged as
  # false divergences. A JS-dispatched click fires a real bubbling click event —
  # exactly what Turbo Drive listens for — so navigation triggers the same way a
  # user's tap would, minus the flake. Turbo swaps are async, so we poll
  # current_path rather than trust a fixed sleep.
  def click_and_navigate(session, el, wait: 5)
    before = session.current_path
    session.execute_script("arguments[0].click()", el)
    deadline = monotonic + wait
    while monotonic < deadline
      return true if session.current_path != before
      sleep 0.1
    end
    false
  end

  def monotonic
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def step_snapshot(session, action)
    { action: action, url: session.current_path, title: (session.title rescue nil) }
  end

  def capture(session, out_dir, slug, n, phase)
    path = File.join(out_dir, format("%s-%02d-%s.png", slug, n, phase))
    session.save_screenshot(path)
    path
  rescue => e
    warn "  ! screenshot #{slug} #{phase}: #{e.class}: #{e.message}"
    nil
  end

  def settle(session)
    session.has_css?("body", wait: 3)
    sleep 0.3
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

  # An admin so every module is reachable and no flow dead-ends on a permission
  # gate. Not an owner (single-owner unique constraint). Idempotent.
  def ensure_sign_in_user!
    user = User.find_or_initialize_by(email_address: SIGN_IN_EMAIL)
    user.password = SIGN_IN_PASSWORD
    user.role = :admin
    user.owner = false
    user.save!
    user
  end

  # Force the demo-data branch in db/seeds.rb on — it's gated behind
  # SEED_DEMO_DATA so a clean test DB still gets the products, tasks, order
  # guides, and log sections the flows need to have something to click into.
  def ensure_demo_data!
    ENV["SEED_DEMO_DATA"] = "true"
    Rails.application.load_seed
  rescue => e
    warn "  ! seed step skipped: #{e.class}: #{e.message}"
  end
end
