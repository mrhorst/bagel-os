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

ActiveRecord::Schema[8.1].define(version: 2026_05_26_000000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.integer "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "follow_up_notes", force: :cascade do |t|
    t.integer "author_id"
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.integer "follow_up_id", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_follow_up_notes_on_author_id"
    t.index ["follow_up_id"], name: "index_follow_up_notes_on_follow_up_id"
  end

  create_table "follow_up_task_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.integer "follow_up_id", null: false
    t.string "link_kind", default: "one_shot", null: false
    t.integer "task_id", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_follow_up_task_links_on_created_by_id"
    t.index ["follow_up_id", "task_id"], name: "index_follow_up_task_links_on_follow_up_id_and_task_id", unique: true
    t.index ["follow_up_id"], name: "index_follow_up_task_links_on_follow_up_id"
    t.index ["task_id"], name: "index_follow_up_task_links_on_task_id"
  end

  create_table "follow_ups", force: :cascade do |t|
    t.integer "assigned_to_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "opened_at", null: false
    t.integer "opened_by_id"
    t.integer "origin_id"
    t.string "origin_type"
    t.text "resolution_note"
    t.datetime "resolved_at"
    t.integer "resolved_by_id"
    t.string "resolved_via"
    t.string "status", default: "open", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "urgency", default: "normal", null: false
    t.index ["assigned_to_id"], name: "index_follow_ups_on_assigned_to_id"
    t.index ["opened_by_id"], name: "index_follow_ups_on_opened_by_id"
    t.index ["origin_type", "origin_id"], name: "index_follow_ups_on_origin"
    t.index ["resolved_by_id"], name: "index_follow_ups_on_resolved_by_id"
    t.index ["status"], name: "index_follow_ups_on_status"
    t.index ["urgency"], name: "index_follow_ups_on_urgency"
  end

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
    t.integer "order_guide_membership_id"
    t.string "presentation"
    t.decimal "quantity_on_hand", precision: 12, scale: 4, null: false
    t.text "raw_text"
    t.string "unit"
    t.datetime "updated_at", null: false
    t.index ["inventory_count_id", "inventory_item_id"], name: "idx_inventory_count_lines_on_count_and_item"
    t.index ["inventory_count_id"], name: "index_inventory_count_lines_on_inventory_count_id"
    t.index ["inventory_item_id"], name: "index_inventory_count_lines_on_inventory_item_id"
    t.index ["order_guide_membership_id"], name: "index_inventory_count_lines_on_order_guide_membership_id"
  end

  create_table "inventory_counts", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "counted_at", null: false
    t.datetime "created_at", null: false
    t.integer "inventory_section_id"
    t.text "notes"
    t.integer "order_guide_id"
    t.json "raw_data", default: {}, null: false
    t.string "source", default: "manual", null: false
    t.string "status", default: "completed", null: false
    t.datetime "updated_at", null: false
    t.index ["counted_at"], name: "index_inventory_counts_on_counted_at"
    t.index ["inventory_section_id"], name: "index_inventory_counts_on_inventory_section_id"
    t.index ["order_guide_id"], name: "index_inventory_counts_on_order_guide_id"
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

  create_table "log_book_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "operating_date", null: false
    t.datetime "submitted_at"
    t.integer "submitted_by_id"
    t.datetime "updated_at", null: false
    t.index ["operating_date"], name: "index_log_book_entries_on_operating_date", unique: true
    t.index ["submitted_by_id"], name: "index_log_book_entries_on_submitted_by_id"
  end

  create_table "log_book_responses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "fields_snapshot"
    t.boolean "flagged_for_follow_up", default: false, null: false
    t.datetime "follow_up_resolved_at"
    t.integer "follow_up_resolved_by_id"
    t.datetime "last_submitted_at"
    t.integer "last_submitted_by_id"
    t.integer "log_book_entry_id", null: false
    t.integer "log_book_section_id", null: false
    t.boolean "no_note", default: false, null: false
    t.string "section_title_snapshot", null: false
    t.string "section_type_snapshot", null: false
    t.datetime "updated_at", null: false
    t.string "urgency", default: "normal", null: false
    t.integer "value_decimals_snapshot"
    t.text "value_grid"
    t.decimal "value_number", precision: 12, scale: 3
    t.text "value_text"
    t.index ["flagged_for_follow_up", "follow_up_resolved_at"], name: "index_log_book_responses_on_follow_up_status"
    t.index ["follow_up_resolved_by_id"], name: "index_log_book_responses_on_follow_up_resolved_by_id"
    t.index ["last_submitted_by_id"], name: "index_log_book_responses_on_last_submitted_by_id"
    t.index ["log_book_entry_id", "log_book_section_id"], name: "index_log_book_responses_on_entry_and_section", unique: true
    t.index ["log_book_entry_id"], name: "index_log_book_responses_on_log_book_entry_id"
    t.index ["log_book_section_id"], name: "index_log_book_responses_on_log_book_section_id"
  end

  create_table "log_book_sections", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.boolean "allow_follow_up", default: true, null: false
    t.boolean "allow_no_note", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "created_by_id"
    t.text "description"
    t.text "fields"
    t.integer "position", default: 0, null: false
    t.boolean "required", default: false, null: false
    t.string "section_type", null: false
    t.string "title", null: false
    t.string "unit_label"
    t.datetime "updated_at", null: false
    t.integer "value_decimals", default: 0, null: false
    t.index ["active"], name: "index_log_book_sections_on_active"
    t.index ["created_by_id"], name: "index_log_book_sections_on_created_by_id"
    t.index ["position", "title"], name: "index_log_book_sections_on_position_and_title"
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

  create_table "order_guide_memberships", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.decimal "buffer_quantity", precision: 12, scale: 4
    t.datetime "created_at", null: false
    t.decimal "expected_usage_quantity", precision: 12, scale: 4
    t.integer "inventory_item_id", null: false
    t.text "notes"
    t.integer "order_guide_id", null: false
    t.integer "order_guide_section_id"
    t.decimal "par", precision: 12, scale: 4
    t.integer "position", default: 0, null: false
    t.integer "preferred_supplier_id"
    t.boolean "primary_guide", default: false, null: false
    t.decimal "reorder_point", precision: 12, scale: 4
    t.string "tracking_mode", default: "counted", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_item_id", "primary_guide"], name: "idx_order_guide_memberships_one_active_primary", unique: true, where: "active = 1 AND primary_guide = 1"
    t.index ["inventory_item_id"], name: "index_order_guide_memberships_on_inventory_item_id"
    t.index ["order_guide_id", "active", "position"], name: "idx_order_guide_memberships_on_guide_active_position"
    t.index ["order_guide_id", "inventory_item_id"], name: "idx_order_guide_memberships_unique_guide_item", unique: true
    t.index ["order_guide_id"], name: "index_order_guide_memberships_on_order_guide_id"
    t.index ["order_guide_section_id"], name: "index_order_guide_memberships_on_order_guide_section_id"
    t.index ["preferred_supplier_id"], name: "index_order_guide_memberships_on_preferred_supplier_id"
  end

  create_table "order_guide_sections", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "order_guide_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["order_guide_id", "active", "position"], name: "idx_on_order_guide_id_active_position_4b70509402"
    t.index ["order_guide_id", "key"], name: "index_order_guide_sections_on_order_guide_id_and_key", unique: true
    t.index ["order_guide_id"], name: "index_order_guide_sections_on_order_guide_id"
  end

  create_table "order_guides", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_order_guides_on_active_and_position"
    t.index ["key"], name: "index_order_guides_on_key", unique: true
  end

  create_table "price_observations", force: :cascade do |t|
    t.integer "case_pack_id"
    t.decimal "case_quantity", precision: 12, scale: 4
    t.datetime "created_at", null: false
    t.decimal "inner_quantity", precision: 12, scale: 4
    t.string "inner_unit_label"
    t.decimal "inner_unit_price", precision: 12, scale: 4
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
    t.string "purchase_kind"
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
    t.decimal "unit_quantity", precision: 12, scale: 4
    t.datetime "updated_at", null: false
    t.index ["case_pack_id"], name: "index_price_observations_on_case_pack_id"
    t.index ["needs_unit_review"], name: "index_price_observations_on_needs_unit_review"
    t.index ["possible_price_spike"], name: "index_price_observations_on_possible_price_spike"
    t.index ["product_id", "observed_at"], name: "index_price_observations_on_product_id_and_observed_at"
    t.index ["product_id", "presentation_key", "observed_at"], name: "idx_price_obs_product_presentation_date"
    t.index ["product_id", "purchase_kind", "observed_at"], name: "idx_price_obs_product_purchase_kind_date"
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
    t.integer "case_pack_id"
    t.decimal "case_quantity", precision: 12, scale: 4
    t.decimal "confidence_score", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.integer "import_batch_id", null: false
    t.decimal "inner_quantity", precision: 12, scale: 4
    t.string "inner_unit_label"
    t.decimal "inner_unit_price", precision: 12, scale: 4
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
    t.decimal "unit_quantity", precision: 12, scale: 4
    t.datetime "updated_at", null: false
    t.index ["case_pack_id"], name: "index_receipt_line_items_on_case_pack_id"
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

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "supplier_product_packs", force: :cascade do |t|
    t.boolean "approved", default: false, null: false
    t.decimal "confidence_score", precision: 5, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.decimal "inner_package_size", precision: 12, scale: 4
    t.string "inner_unit_label", default: "unit", null: false
    t.string "inner_unit_of_measure"
    t.text "notes"
    t.integer "product_id"
    t.string "purchase_kind", default: "case", null: false
    t.json "raw_data", default: {}, null: false
    t.string "raw_name"
    t.string "raw_sku"
    t.string "source", default: "manual", null: false
    t.string "source_label"
    t.datetime "source_snapshot_at"
    t.string "standard_unit"
    t.integer "supplier_id", null: false
    t.decimal "units_per_case", precision: 12, scale: 4, null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "approved"], name: "index_supplier_product_packs_on_product_id_and_approved"
    t.index ["product_id"], name: "index_supplier_product_packs_on_product_id"
    t.index ["supplier_id", "raw_name"], name: "index_supplier_product_packs_on_supplier_id_and_raw_name"
    t.index ["supplier_id", "raw_sku"], name: "index_supplier_product_packs_on_supplier_id_and_raw_sku"
    t.index ["supplier_id"], name: "index_supplier_product_packs_on_supplier_id"
  end

  create_table "suppliers", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_suppliers_on_name", unique: true
  end

  create_table "task_completions", force: :cascade do |t|
    t.datetime "completed_at", null: false
    t.datetime "created_at", null: false
    t.text "notes"
    t.string "snapshot_staff_name", null: false
    t.string "snapshot_undone_by_staff_name"
    t.integer "task_occurrence_id", null: false
    t.datetime "undone_at"
    t.integer "undone_by_user_id"
    t.text "undone_note"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["task_occurrence_id"], name: "idx_task_completions_one_active", unique: true, where: "undone_at IS NULL"
    t.index ["task_occurrence_id"], name: "index_task_completions_on_task_occurrence_id"
    t.index ["undone_at"], name: "index_task_completions_on_undone_at"
    t.index ["undone_by_user_id"], name: "index_task_completions_on_undone_by_user_id"
    t.index ["user_id"], name: "index_task_completions_on_user_id"
  end

  create_table "task_lists", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.time "display_end_time"
    t.time "display_start_time"
    t.string "key", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active", "position"], name: "index_task_lists_on_active_and_position"
    t.index ["key"], name: "index_task_lists_on_key", unique: true
  end

  create_table "task_occurrences", force: :cascade do |t|
    t.datetime "completion_window_ends_at"
    t.datetime "created_at", null: false
    t.datetime "due_at"
    t.date "period_ends_on", null: false
    t.string "period_kind", null: false
    t.date "period_starts_on", null: false
    t.integer "position", default: 0, null: false
    t.boolean "requires_photo_evidence", default: false, null: false
    t.text "snapshot_instructions"
    t.string "snapshot_list_name", null: false
    t.string "snapshot_title", null: false
    t.integer "task_id", null: false
    t.integer "task_list_id", null: false
    t.datetime "updated_at", null: false
    t.index ["completion_window_ends_at"], name: "index_task_occurrences_on_completion_window_ends_at"
    t.index ["due_at"], name: "index_task_occurrences_on_due_at"
    t.index ["period_kind", "period_starts_on", "period_ends_on"], name: "idx_task_occurrences_period"
    t.index ["task_id", "period_kind", "period_starts_on"], name: "idx_task_occurrences_unique_period", unique: true
    t.index ["task_id"], name: "index_task_occurrences_on_task_id"
    t.index ["task_list_id"], name: "index_task_occurrences_on_task_list_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.time "due_time"
    t.date "ends_on"
    t.text "instructions"
    t.date "one_time_on"
    t.integer "position", default: 0, null: false
    t.string "recurrence_type", null: false
    t.boolean "requires_photo_evidence", default: false, null: false
    t.date "starts_on"
    t.integer "task_list_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.json "weekdays", default: [], null: false
    t.index ["recurrence_type"], name: "index_tasks_on_recurrence_type"
    t.index ["task_list_id", "active", "position"], name: "index_tasks_on_task_list_id_and_active_and_position"
    t.index ["task_list_id"], name: "index_tasks_on_task_list_id"
  end

  create_table "user_module_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "module_name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "module_name"], name: "index_user_module_permissions_on_user_id_and_module_name", unique: true
    t.index ["user_id"], name: "index_user_module_permissions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name"
    t.boolean "owner", default: false, null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["owner"], name: "index_users_on_owner", unique: true, where: "owner = TRUE"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object", limit: 1073741823
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "follow_up_notes", "follow_ups"
  add_foreign_key "follow_up_notes", "users", column: "author_id"
  add_foreign_key "follow_up_task_links", "follow_ups"
  add_foreign_key "follow_up_task_links", "tasks"
  add_foreign_key "follow_up_task_links", "users", column: "created_by_id"
  add_foreign_key "follow_ups", "users", column: "assigned_to_id"
  add_foreign_key "follow_ups", "users", column: "opened_by_id"
  add_foreign_key "follow_ups", "users", column: "resolved_by_id"
  add_foreign_key "import_batches", "suppliers"
  add_foreign_key "inventory_count_lines", "inventory_counts"
  add_foreign_key "inventory_count_lines", "inventory_items"
  add_foreign_key "inventory_count_lines", "order_guide_memberships"
  add_foreign_key "inventory_counts", "inventory_sections"
  add_foreign_key "inventory_counts", "order_guides"
  add_foreign_key "inventory_items", "inventory_sections"
  add_foreign_key "inventory_items", "products"
  add_foreign_key "inventory_items", "suppliers", column: "preferred_supplier_id"
  add_foreign_key "log_book_entries", "users", column: "submitted_by_id"
  add_foreign_key "log_book_responses", "log_book_entries"
  add_foreign_key "log_book_responses", "log_book_sections"
  add_foreign_key "log_book_responses", "users", column: "follow_up_resolved_by_id"
  add_foreign_key "log_book_responses", "users", column: "last_submitted_by_id"
  add_foreign_key "log_book_sections", "users", column: "created_by_id"
  add_foreign_key "normalization_reviews", "products"
  add_foreign_key "normalization_reviews", "receipt_line_items"
  add_foreign_key "order_guide_items", "inventory_items"
  add_foreign_key "order_guide_items", "order_guide_imports"
  add_foreign_key "order_guide_memberships", "inventory_items"
  add_foreign_key "order_guide_memberships", "order_guide_sections"
  add_foreign_key "order_guide_memberships", "order_guides"
  add_foreign_key "order_guide_memberships", "suppliers", column: "preferred_supplier_id"
  add_foreign_key "order_guide_sections", "order_guides"
  add_foreign_key "price_observations", "products"
  add_foreign_key "price_observations", "receipt_line_items"
  add_foreign_key "price_observations", "supplier_product_packs", column: "case_pack_id"
  add_foreign_key "price_observations", "suppliers"
  add_foreign_key "product_aliases", "products"
  add_foreign_key "products", "product_categories"
  add_foreign_key "products", "suppliers"
  add_foreign_key "receipt_line_items", "import_batches"
  add_foreign_key "receipt_line_items", "products"
  add_foreign_key "receipt_line_items", "receipts"
  add_foreign_key "receipt_line_items", "supplier_product_packs", column: "case_pack_id"
  add_foreign_key "receipt_line_items", "suppliers"
  add_foreign_key "receipts", "import_batches"
  add_foreign_key "receipts", "suppliers"
  add_foreign_key "sessions", "users"
  add_foreign_key "supplier_product_packs", "products"
  add_foreign_key "supplier_product_packs", "suppliers"
  add_foreign_key "task_completions", "task_occurrences"
  add_foreign_key "task_completions", "users"
  add_foreign_key "task_completions", "users", column: "undone_by_user_id"
  add_foreign_key "task_occurrences", "task_lists"
  add_foreign_key "task_occurrences", "tasks"
  add_foreign_key "tasks", "task_lists"
  add_foreign_key "user_module_permissions", "users"
end
