module ProductsHelper
  # The catalog-narrowing params on the products index. `sort` and `per_page`
  # are presentation preferences, not filters, so clearing filters keeps them.
  PRODUCT_FILTER_KEYS = %w[q category_id supplier_id needs_review no_standard_unit_price missing_category show_hidden].freeze

  # True when the products list is narrowed by any search/filter. The three
  # checkboxes submit "0" when unticked (they carry a hidden "0" companion), so
  # only "1" counts as active for them.
  def product_filters_active?(params)
    PRODUCT_FILTER_KEYS.any? do |key|
      value = params[key].to_s
      key.in?(%w[q category_id supplier_id]) ? value.present? : value == "1"
    end
  end

  # Path back to the unfiltered catalog, preserving the chosen sort and page
  # size (and dropping `page`, so the reset view starts at page 1).
  def products_cleared_filters_path(query_parameters)
    products_path(query_parameters.to_h.slice("sort", "per_page").compact_blank)
  end
end
