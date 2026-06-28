Supplier.primary

[
  { title: "General Log", description: "Anything important from today's shift.", section_type: "long_text", position: 1 },
  { title: "Maintenance", description: "Equipment, plumbing, repairs, or facility issues.", section_type: "long_text", position: 2 },
  { title: "Follow-ups", description: "Anything tomorrow's manager or owner needs to see.", section_type: "long_text", position: 3 }
].each do |attrs|
  section = LogBookSection.find_or_initialize_by(title: attrs.fetch(:title))
  section.assign_attributes(attrs)
  section.active = true
  section.allow_no_note = true
  section.save!
end

[
  "Bakery ingredients",
  "Dairy",
  "Cream cheese / spreads",
  "Eggs",
  "Meat",
  "Fish / seafood",
  "Produce",
  "Beverages",
  "Dry goods",
  "Frozen",
  "Condiments",
  "Coffee / tea",
  "Paper goods",
  "Packaging",
  "Cleaning supplies",
  "Smallwares",
  "Equipment / maintenance",
  "Other / unknown"
].each_with_index do |name, index|
  ProductCategory.find_or_create_by!(name: name) do |category|
    category.sort_order = index + 1
  end
end

# Generic, non-private demo data for hands-on environments: local development
# and the deployed staging install (which runs RAILS_ENV=production, so it opts
# in via SEED_DEMO_DATA=true — see the `seed_demo` alias in config/deploy.yml).
if Rails.env.development? || ENV["SEED_DEMO_DATA"] == "true"
  demo_guides = [
    [ "Daily", 1 ],
    [ "Weekly", 2 ],
    [ "Every 2 weeks", 3 ],
    [ "Cleaning Supplies", 4 ]
  ].to_h do |name, position|
    guide = OrderGuide.find_or_initialize_by(key: OrderGuide.key_for(name))
    guide.name = name
    guide.position = position
    guide.active = true
    guide.save!
    [ name, guide ]
  end

  demo_sections = [
    [ "Walk-in cooler", 1 ],
    [ "Dry storage", 2 ],
    [ "Paper and packaging", 3 ],
    [ "Cleaning closet", 4 ]
  ].to_h do |name, position|
    section = InventorySection.find_or_initialize_by(name: name)
    section.position = position
    section.save!
    [ name, section ]
  end

  demo_items = [
    { name: "Eggs", category: "Eggs", section: "Walk-in cooler", guide: "Daily", count_unit: "case", pack_size: "case", position: 1 },
    { name: "Whole milk", category: "Dairy", section: "Walk-in cooler", guide: "Daily", count_unit: "gallon", pack_size: "gallon", position: 2 },
    { name: "Plain cream cheese", category: "Cream cheese / spreads", section: "Walk-in cooler", guide: "Daily", count_unit: "tub", pack_size: "tub", position: 3 },
    { name: "Bacon", category: "Meat", section: "Walk-in cooler", guide: "Weekly", count_unit: "case", pack_size: "case", position: 4 },
    { name: "Coffee beans", category: "Coffee / tea", section: "Dry storage", guide: "Weekly", count_unit: "bag", pack_size: "bag", position: 5 },
    { name: "All-purpose flour", category: "Bakery ingredients", section: "Dry storage", guide: "Weekly", count_unit: "bag", pack_size: "bag", position: 6 },
    { name: "Napkins", category: "Paper goods", section: "Paper and packaging", guide: "Every 2 weeks", count_unit: "case", pack_size: "case", position: 7 },
    { name: "To-go cups", category: "Packaging", section: "Paper and packaging", guide: "Every 2 weeks", count_unit: "sleeve", pack_size: "case", position: 8 },
    { name: "Sanitizer solution", category: "Cleaning supplies", section: "Cleaning closet", guide: "Cleaning Supplies", count_unit: "jug", pack_size: "jug", position: 9 },
    { name: "Trash bags", category: "Cleaning supplies", section: "Cleaning closet", guide: "Cleaning Supplies", count_unit: "roll", pack_size: "case", position: 10 }
  ]

  demo_items.each do |seed_item|
    category = ProductCategory.find_by!(name: seed_item.fetch(:category))
    product = Supplier.primary.products.find_or_initialize_by(canonical_name: seed_item.fetch(:name))
    product.product_category = category
    product.active = true
    product.save!

    item = InventoryItem.find_or_initialize_by(key: InventoryItem.key_for(seed_item.fetch(:name)))
    item.name = seed_item.fetch(:name)
    item.product = product
    item.inventory_section = demo_sections.fetch(seed_item.fetch(:section))
    item.category = seed_item.fetch(:category)
    item.count_unit = seed_item.fetch(:count_unit)
    item.pack_size = seed_item.fetch(:pack_size)
    item.position = seed_item.fetch(:position)
    item.active = true
    item.needs_review = false
    item.save!
    item.assign_primary_order_guide!(demo_guides.fetch(seed_item.fetch(:guide)))
  end

  # ── Demo recipes ─────────────────────────────────────────────────────
  # Generic house recipes so the Recipes module has something to open.
  # Ingredient lines and costing build on these (#242, #243).
  [
    {
      name: "Plain bagel dough", description: "House bagel dough. Mix, proof, shape, boil, bake.", position: 1,
      ingredients: [
        { item: "All-purpose flour", quantity: 5, unit: "lb" },
        { item: "Eggs", quantity: 2, unit: "each" }
      ]
    },
    {
      name: "Scallion cream cheese", description: "Whip plain cream cheese with chopped scallions.", position: 2,
      ingredients: [
        { item: "Plain cream cheese", quantity: 1, unit: "tub" }
      ]
    }
  ].each do |attrs|
    recipe = Recipe.find_or_initialize_by(name: attrs.fetch(:name))
    recipe.description = attrs.fetch(:description)
    recipe.position = attrs.fetch(:position)
    recipe.active = true
    recipe.save!

    attrs.fetch(:ingredients, []).each_with_index do |line, index|
      item = InventoryItem.find_by(key: InventoryItem.key_for(line.fetch(:item)))
      ingredient = recipe.recipe_ingredients.find_or_initialize_by(inventory_item: item)
      ingredient.name = line.fetch(:item)
      ingredient.quantity = line[:quantity]
      ingredient.unit = line[:unit]
      ingredient.position = index + 1
      ingredient.save!
    end
  end

  # ── Demo task lists ──────────────────────────────────────────────────
  # Three always-visible lists (no display_start_time / display_end_time)
  # so the dashboard's list picker has real choices to offer, and the
  # tasks themselves don't go "late" because they have no due_time.
  demo_task_lists = [
    { name: "Prep", position: 1 },
    { name: "Front of house", position: 2 },
    { name: "Cleaning", position: 3 }
  ].map do |list_attrs|
    list = TaskList.find_or_initialize_by(key: TaskList.key_for(list_attrs.fetch(:name)))
    list.name = list_attrs.fetch(:name)
    list.position = list_attrs.fetch(:position)
    list.active = true
    list.display_start_time = nil
    list.display_end_time = nil
    list.save!
    [ list_attrs.fetch(:name), list ]
  end.to_h

  # Model requires due_time for daily/weekly tasks — use end-of-day so
  # they stay "open" all day instead of going late. Monthly tasks don't
  # need a due_time at all.
  end_of_day = Time.zone.parse("23:59")

  demo_tasks = [
    # Prep — daily, due by end of day
    { list: "Prep", title: "Pull cream cheese from walk-in",      recurrence_type: "daily", position: 1, due_time: end_of_day },
    { list: "Prep", title: "Slice tomatoes for the line",         recurrence_type: "daily", position: 2, due_time: end_of_day },
    { list: "Prep", title: "Restock cream cheese station",        recurrence_type: "daily", position: 3, due_time: end_of_day, requires_photo_evidence: true },

    # Front of house — daily, due by end of day
    { list: "Front of house", title: "Wipe down counters",        recurrence_type: "daily", position: 1, due_time: end_of_day },
    { list: "Front of house", title: "Refill napkin dispensers",  recurrence_type: "daily", position: 2, due_time: end_of_day },
    { list: "Front of house", title: "Check napkin stock under register", recurrence_type: "daily", position: 3, due_time: end_of_day },

    # Cleaning — mix of daily + weekly + monthly (monthly = no due time)
    { list: "Cleaning", title: "Sweep front of house",            recurrence_type: "daily",   position: 1, due_time: end_of_day },
    { list: "Cleaning", title: "Deep-clean espresso machine",     recurrence_type: "weekly",  position: 2, due_time: end_of_day, weekdays: [ 1 ] },
    { list: "Cleaning", title: "Descale dish sink",               recurrence_type: "monthly", position: 3 }
  ]

  demo_tasks.each do |attrs|
    list = demo_task_lists.fetch(attrs.fetch(:list))
    task = list.tasks.find_or_initialize_by(title: attrs.fetch(:title))
    task.recurrence_type        = attrs.fetch(:recurrence_type)
    task.position               = attrs.fetch(:position)
    task.requires_photo_evidence = attrs.fetch(:requires_photo_evidence, false)
    task.due_time               = attrs[:due_time]
    task.weekdays               = attrs[:weekdays] if attrs[:weekdays].present?
    task.starts_on              ||= Date.current - 1
    task.active                 = true
    task.save!
  end

  # ── Demo follow-ups ─────────────────────────────────────────────────
  # A couple of open follow-ups so the Follow-ups journey (Shift →
  # Follow-ups → open an item → back) has something to click into. The
  # index defaults to the "open" scope, so these must stay open to show.
  # Generic, non-private demo content. Idempotent on title.
  demo_follow_ups = [
    { title: "Walk-in cooler running a few degrees warm", urgency: "important",
      description: "Noticed the walk-in reading higher than usual at open. Keep an eye on it through the day and call for service if it keeps climbing." },
    { title: "Reorder to-go cups before the weekend", urgency: "normal",
      description: "Down to the last sleeve on the line. Make sure they land on the next order guide." }
  ]

  demo_follow_ups.each do |attrs|
    follow_up = FollowUp.find_or_initialize_by(title: attrs.fetch(:title))
    follow_up.urgency     = attrs.fetch(:urgency)
    follow_up.status      = "open"
    follow_up.description = attrs.fetch(:description)
    follow_up.opened_at ||= Time.current
    follow_up.save!
  end

  # ── Demo receipt import ─────────────────────────────────────────────
  # One imported receipt batch so the Imports journey (Buying → Imports →
  # open a batch → back) has a row to click into, and so the batch detail
  # (with its receipt lines) renders for hand-probes. Generic, non-private
  # demo content. Idempotent on the batch's unique file_checksum.
  demo_supplier = Supplier.primary

  import_batch = ImportBatch.find_or_initialize_by(file_checksum: "demo-receipt-0001")
  import_batch.supplier        = demo_supplier
  import_batch.source_filename = "demo-receipt-2026-06-01.csv"
  import_batch.status          = "imported"
  import_batch.imported_at   ||= Time.current
  import_batch.rows_processed  = 2
  import_batch.rows_imported   = 2
  import_batch.rows_failed     = 0
  import_batch.save!

  receipt = Receipt.find_or_initialize_by(supplier: demo_supplier, receipt_number: "DEMO-0001")
  receipt.import_batch = import_batch
  receipt.purchased_at ||= Time.current
  receipt.subtotal = 86.50
  receipt.tax      = 0.00
  receipt.total    = 86.50
  receipt.save!

  demo_lines = [
    { line_number: 1, raw_name: "All-purpose flour, 50 lb bag", raw_sku: "FLR-50",
      unit_quantity: 2, line_total: 54.00, needs_review: false },
    { line_number: 2, raw_name: "Whole milk, 4 x 1 gal", raw_sku: "MLK-4G",
      unit_quantity: 1, line_total: 32.50, needs_review: true }
  ]

  demo_lines.each do |attrs|
    line = ReceiptLineItem.find_or_initialize_by(import_batch: import_batch, line_number: attrs.fetch(:line_number))
    line.receipt       = receipt
    line.supplier      = demo_supplier
    line.line_type     = "item"
    line.raw_name      = attrs.fetch(:raw_name)
    line.raw_sku       = attrs.fetch(:raw_sku)
    line.unit_quantity = attrs.fetch(:unit_quantity)
    line.line_total    = attrs.fetch(:line_total)
    line.needs_review  = attrs.fetch(:needs_review)
    line.row_checksum  = "demo-receipt-0001-line-#{attrs.fetch(:line_number)}"
    line.save!

    # Keep the invariant the app assumes — needs_review ⟺ a pending review
    # exists — so a flagged demo line is actually resolvable from the edit page
    # rather than a dead-end (#172). The demo line carries no derivable
    # comparable price, so a "price" review is the right thing to resolve.
    if line.needs_review? && line.normalization_reviews.pending.none?
      line.normalization_reviews.create!(
        issue_type: "price",
        status: "pending",
        description: Purchasing::ReceiptLineNormalizer::PRICE_REVIEW
      )
    end
  end
end
