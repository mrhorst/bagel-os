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
