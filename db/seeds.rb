Supplier.primary

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

if Rails.env.development?
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
end
