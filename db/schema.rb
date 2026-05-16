# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_05_14_231500) do
  create_table "import_batches", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "file_checksum", null: false
    t.datetime "imported_at", null: false
    t.text "notes"
    t.integer "rows_failed", default: 0, null: false
    t.integer "rows_imported", default: 0, null: false
    t.integer "rows_processed", default: 0, null: false
    t.string "source_filename", null: false
    t.string "source_path"
    t.string "status", default: "pending", null: false
    t.integer "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.json "validation_summary", default: {}, null: false
    t.index ["file_checksum"], name: "index_import_batches_on_file_checksum", unique: true
    t.index ["status"], name: "index_import_batches_on_status"
    t.index ["supplier_id", "source_filename"], name: "index_import_batches_on_supplier_id_and_source_filename"
    t.index ["supplier_id"], name: "index_import_batches_on_supplier_id"
  end

  create_table "inventory_count_lines", force: :cascade do |t|
    t.decimal "confidence", precision: 5, scale: 2, default: "1.0", null: false
    t.datetime "created_at", null: false
    t.integer "inventory_count_id", null: false
    t.integer "inventory_item_id", null: false
    t.text "notes"
    t.string "presentation"
    t.decimal "quantity_on_hand", precision: 12, scale: 4, null: false
    t.text "raw_text"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["inventory_count_id", "inventory_item_id"], name: "idx_inventory_count_lines_on_count_and_item"
    t.index ["inventory_count_id"], name: "index_inventory_count_lines_on_inventory_count_id"
    t.index ["inventory_item_id"], name: "index_inventory_count_lines_on_inventory_item_id"
  end

  create_table "inventory_counts", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "counted_at", null: false
    t.datetime "created_at", null: false
    t.integer "inventory_section_id"
    t.text "notes"
    t.json "raw_data", default: {}, null: false
    t.string "source", default: "manual", null: false
    t.string "status", default: "completed", null: false
    t.datetime "updated_at", null: false
    t.index ["counted_at"], name: "index_inventory_counts_on_counted_at"
    t.index ["inventory_section_id"], name: "index_inventory_counts_on_inventory_section_id"
    t.index ["status"], name: "index_inventory_counts_on_status"
  end

  create_table "inventory_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "category"
    t.string "count_unit"
    t.datetime "created_at", null: false
    t.decimal "current_par", precision: 12, scale: 4
    t.string "guide_frequency", default: "manual", null: false
    t.integer "inventory_section_id"
    t.string "key", null: false
    t.string "name", null: false
    t.boolean "needs_review", default: false, null: false
    t.text "notes"
    t.string "pack_size"
    t.integer "position", default: 0, null: false
    t.integer "preferred_supplier_id"
    t.integer "product_id"
    t.json "raw_data", default: {}, null: false
    t.decimal "reorder_point", precision: 12, scale: 4
    t.string "subcategory"
    t.datetime "updated_at", null: false
    t.index ["guide_frequency"], name: "index_inventory_items_on_guide_frequency"
    t.index ["inventory_section_id", "position"], name: "index_inventory_items_on_inventory_section_id_and_position"
    t.index ["inventory_section_id"], name: "index_inventory_items_on_inventory_section_id"
    t.index ["key"], name: "index_inventory_items_on_key", unique: true
    t.index ["needs_review"], name: "index_inventory_items_on_needs_review"
    t.index ["preferred_supplier_id"], name: "index_inventory_items_on_preferred_supplier_id"
    t.index ["product_id"], name: "index_inventory_items_on_product_id"
  end

  create_table "inventory_sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_inventory_sections_on_name", unique: true
  end

  create_table "normalization_reviews", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.string "issue_type", null: false
    t.integer "product_id"
    t.integer "receipt_line_item_id", null: false
    t.text "resolution_notes"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["issue_type"], name: "index_normalization_reviews_on_issue_type"
    t.index ["product_id"], name: "index_normalization_reviews_on_product_id"
    t.index ["receipt_line_item_id"], name: "index_normalization_reviews_on_receipt_line_item_id"
    t.index ["status"], name: "index_normalization_reviews_on_status"
  end

  create_table "order_guide_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "file_checksum", null: false
    t.string "guide_type", null: false
    t.datetime "imported_at", null: false
    t.text "notes"
    t.text "raw_text"
    t.integer "rows_imported", default: 0, null: false
    t.string "source_filename", null: false
    t.string "source_path"
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.json "validation_summary", default: {}, null: false
    t.index ["file_checksum"], name: "index_order_guide_imports_on_file_checksum", unique: true
    t.index ["guide_type", "imported_at"], name: "index_order_guide_imports_on_guide_type_and_imported_at"
    t.index ["status"], name: "index_order_guide_imports_on_status"
  end

  create_table "order_guide_items", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "guide_sku"
    t.string "guide_type", null: false
    t.integer "inventory_item_id"
    t.string "item_name", null: false
    t.decimal "match_confidence", precision: 5, scale: 2, default: "0.0", null: false
    t.boolean "needs_review", default: false, null: false
    t.integer "order_guide_import_id", null: false
    t.string "pack_quantity"
    t.string "par_text"
    t.integer "position", default: 0, null: false
    t.json "raw_data", default: {}, null: false
    t.text "raw_line", null: false
    t.string "section_name", null: false
    t.string "subcategory"
    t.string "sunday_target"
    t.string "thursday_target"
    t.datetime "updated_at", null: false
    t.index ["guide_type", "active"], name: "index_order_guide_items_on_guide_type_and_active"
    t.index ["inventory_item_id"], name: "index_order_guide_items_on_inventory_item_id"
    t.index ["needs_review"], name: "index_order_guide_items_on_needs_review"
    t.index ["order_guide_import_id"], name: "index_order_guide_items_on_order_guide_import_id"
    t.index ["section_name", "position"], name: "index_order_guide_items_on_section_name_and_position"
  end

  create_table "price_observations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.decimal "line_total", precision: 12, scale: 2
    t.boolean "needs_unit_review", default: false, null: false
    t.text "notes"
    t.datetime "observed_at", null: false
    t.decimal "package_price", precision: 12, scale: 4
    t.decimal "package_size", precision: 12, scale: 4
    t.decimal "percent_above_recent_average", precision: 8, scale: 2
    t.boolean "possible_price_spike", default: false, null: false
    t.string "presentation_key"
    t.string "presentation_label"
    t.string "price_basis", default: "presentation", null: false
    t.integer "product_id", null: false
    t.decimal "quantity", precision: 12, scale: 4
    t.integer "receipt_line_item_id", null: false
    t.string "source_filename", null: false
    t.decimal "standard_quantity", precision: 12, scale: 4
    t.string "standard_unit"
    t.decimal "standard_unit_price", precision: 12, scale: 4
    t.integer "supplier_id", null: false
    t.decimal "unit_confidence", precision: 5, scale: 2
    t.string "unit_of_measure"
    t.decimal "unit_price", precision: 12, scale: 4
    t.datetime "updated_at", null: false
    t.index ["needs_unit_review"], name: "index_price_observations_on_needs_unit_review"
    t.index ["possible_price_spike"], name: "index_price_observations_on_possible_price_spike"
    t.index ["product_id", "observed_at"], name: "index_price_observations_on_product_id_and_observed_at"
    t.index ["product_id", "presentation_key", "observed_at"], name: "idx_price_obs_product_presentation_date"
    t.index ["product_id", "standard_unit", "observed_at"], name: "idx_price_obs_product_standard_unit_date"
    t.index ["product_id"], name: "index_price_observations_on_product_id"
    t.index ["receipt_line_item_id"], name: "index_price_observations_on_receipt_line_item_id", unique: true
    t.index ["supplier_id"], name: "index_price_observations_on_supplier_id"
  end

  create_table "product_aliases", force: :cascade do |t|
    t.boolean "approved", default: false, null: false
    t.decimal "confidence_score", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.integer "product_id", null: false
    t.string "raw_name", null: false
    t.string "raw_sku"
    t.datetime "updated_at", null: false
    t.index ["approved"], name: "index_product_aliases_on_approved"
    t.index ["product_id", "raw_name", "raw_sku"], name: "index_product_aliases_on_product_id_and_raw_name_and_raw_sku", unique: true
    t.index ["product_id"], name: "index_product_aliases_on_product_id"
    t.index ["raw_sku"], name: "index_product_aliases_on_raw_sku"
  end

  create_table "product_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name", null: false
    t.integer "sort_order", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_product_categories_on_name", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "canonical_name", null: false
    t.datetime "created_at", null: false
    t.boolean "needs_review", default: true, null: false
    t.text "notes"
    t.decimal "package_size", precision: 12, scale: 4
    t.integer "product_category_id"
    t.string "purchase_unit"
    t.string "standard_unit"
    t.integer "supplier_id", null: false
    t.string "supplier_sku"
    t.string "unit_of_measure"
    t.datetime "updated_at", null: false
    t.index ["canonical_name"], name: "index_products_on_canonical_name"
    t.index ["needs_review"], name: "index_products_on_needs_review"
    t.index ["product_category_id"], name: "index_products_on_product_category_id"
    t.index ["supplier_id", "supplier_sku"], name: "index_products_on_supplier_id_and_supplier_sku", unique: true, where: "supplier_sku IS NOT NULL"
    t.index ["supplier_id"], name: "index_products_on_supplier_id"
  end

  create_table "receipt_line_items", force: :cascade do |t|
    t.decimal "confidence_score", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.integer "import_batch_id", null: false
    t.integer "line_number", null: false
    t.decimal "line_total", precision: 12, scale: 2
    t.string "line_type", default: "item", null: false
    t.boolean "needs_review", default: true, null: false
    t.decimal "package_price", precision: 12, scale: 4
    t.decimal "parsed_package_size", precision: 12, scale: 4
    t.string "parsed_unit_of_measure"
    t.integer "product_id"
    t.decimal "quantity", precision: 12, scale: 4
    t.string "raw_case_quantity"
    t.json "raw_data", default: {}, null: false
    t.string "raw_name", null: false
    t.string "raw_package_description"
    t.string "raw_quantity"
    t.string "raw_sku"
    t.string "raw_unit"
    t.integer "receipt_id", null: false
    t.string "row_checksum", null: false
    t.integer "supplier_id", null: false
    t.datetime "updated_at", null: false
    t.index ["import_batch_id", "line_number"], name: "index_receipt_line_items_on_import_batch_id_and_line_number", unique: true
    t.index ["import_batch_id"], name: "index_receipt_line_items_on_import_batch_id"
    t.index ["line_type"], name: "index_receipt_line_items_on_line_type"
    t.index ["needs_review"], name: "index_receipt_line_items_on_needs_review"
    t.index ["product_id"], name: "index_receipt_line_items_on_product_id"
    t.index ["raw_sku"], name: "index_receipt_line_items_on_raw_sku"
    t.index ["receipt_id"], name: "index_receipt_line_items_on_receipt_id"
    t.index ["row_checksum"], name: "index_receipt_line_items_on_row_checksum"
    t.index ["supplier_id"], name: "index_receipt_line_items_on_supplier_id"
  end

  create_table "receipts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "import_batch_id", null: false
    t.datetime "purchased_at"
    t.json "raw_data", default: {}, null: false
    t.string "receipt_number", null: false
    t.decimal "subtotal", precision: 12, scale: 2
    t.integer "supplier_id", null: false
    t.decimal "tax", precision: 12, scale: 2
    t.decimal "total", precision: 12, scale: 2
    t.datetime "updated_at", null: false
    t.index ["import_batch_id"], name: "index_receipts_on_import_batch_id"
    t.index ["purchased_at"], name: "index_receipts_on_purchased_at"
    t.index ["supplier_id", "receipt_number"], name: "index_receipts_on_supplier_id_and_receipt_number", unique: true
    t.index ["supplier_id"], name: "index_receipts_on_supplier_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_suppliers_on_name", unique: true
  end

  add_foreign_key "import_batches", "suppliers"
  add_foreign_key "inventory_count_lines", "inventory_counts"
  add_foreign_key "inventory_count_lines", "inventory_items"
  add_foreign_key "inventory_counts", "inventory_sections"
  add_foreign_key "inventory_items", "inventory_sections"
  add_foreign_key "inventory_items", "products"
  add_foreign_key "inventory_items", "suppliers", column: "preferred_supplier_id"
  add_foreign_key "normalization_reviews", "products"
  add_foreign_key "normalization_reviews", "receipt_line_items"
  add_foreign_key "order_guide_items", "inventory_items"
  add_foreign_key "order_guide_items", "order_guide_imports"
  add_foreign_key "price_observations", "products"
  add_foreign_key "price_observations", "receipt_line_items"
  add_foreign_key "price_observations", "suppliers"
  add_foreign_key "product_aliases", "products"
  add_foreign_key "products", "product_categories"
  add_foreign_key "products", "suppliers"
  add_foreign_key "receipt_line_items", "import_batches"
  add_foreign_key "receipt_line_items", "products"
  add_foreign_key "receipt_line_items", "receipts"
  add_foreign_key "receipt_line_items", "suppliers"
  add_foreign_key "receipts", "import_batches"
  add_foreign_key "receipts", "suppliers"
end
