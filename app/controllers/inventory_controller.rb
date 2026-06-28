class InventoryController < ApplicationController
  require_module_access :inventory

  def index
    @inventory_item_count = InventoryItem.active.count
    @linked_inventory_item_count = InventoryItem.active.where.not(product_id: nil).count
    @guide_item_count = OrderGuideItem.active.count
    @guide_items_needing_review = OrderGuideItem.active.needs_review.count
    @latest_count = InventoryCount.recent_first.first
    @missing_products = Purchasing::InventoryGapAnalyzer.new.missing_products(limit: 12)
    @order_guides = OrderGuide.active.ordered.includes(:order_guide_memberships)
  end

  def items
    @order_guides = OrderGuide.active.ordered
    @sections = InventorySection.ordered.includes(inventory_items: [ :product, :preferred_supplier, order_guide_memberships: :order_guide ])
    @unsectioned_items = InventoryItem.active.where(inventory_section_id: nil).ordered.includes(order_guide_memberships: :order_guide)
    @items_needing_review = InventoryItem.active.needs_review.order(:name)
  end

  def shopping_list
    @order_guides = OrderGuide.active.ordered

    if params[:order_guide_id].present?
      @order_guide = OrderGuide.active.find(params[:order_guide_id])
      recommendation = Purchasing::OrderGuideRecommendation.new(@order_guide)
      @recommendations = recommendation.rows
      @buy_now = @recommendations.select { |row| row.status == "buy_now" }
      @not_counted = @recommendations.select { |row| row.status == "not_counted" }
      @setup_needed = @recommendations.select { |row| row.status == "setup_needed" }
      @order_only = @recommendations.select { |row| row.status == "order_only" }
    else
      @recommendations = Purchasing::InventoryRecommendation.new.rows
      @buy_now = @recommendations.select { |row| row.status == "buy_now" }
      @not_counted = @recommendations.select { |row| row.status == "not_counted" }
      @setup_needed = []
      @order_only = []
    end
  end

  def counts
    @counts = InventoryCount.recent_first.includes(:inventory_section, :order_guide, :inventory_count_lines).limit(30)
  end

  def count
    @count = InventoryCount.includes(
      :order_guide,
      inventory_count_lines: [ :inventory_item, { order_guide_membership: :order_guide_section } ]
    ).find(params[:id])
    @lines = @count.inventory_count_lines.sort_by { |line| count_line_sort_key(line) }
  end

  def new_count
    @order_guides = OrderGuide.active.ordered
    return if params[:order_guide_id].blank?

    @order_guide = OrderGuide.active.find(params[:order_guide_id])
    @memberships = counted_memberships_for(@order_guide)
  end

  def create_count
    if params[:order_guide_id].present?
      create_guide_count
    else
      create_legacy_count
    end
  end

  def update_primary_order_guide
    item = InventoryItem.find(params[:id])
    guide = OrderGuide.active.find_by(id: params[:order_guide_id].presence)
    item.assign_primary_order_guide!(guide)

    # Confirm what actually happened: name the guide when one was set, and say
    # "cleared" when "No primary guide" was chosen. The old single message
    # ("Updated … primary guide") read the same either way — after picking "No
    # primary guide" it sounded like a guide was still set, leaving the user
    # unsure the clear took.
    notice =
      if guide
        "Set #{item.name}'s primary guide to #{guide.name}."
      else
        "Cleared #{item.name}'s primary guide."
      end
    redirect_back fallback_location: inventory_items_path, notice: notice
  end

  private

  def create_guide_count
    order_guide = OrderGuide.active.find_by(id: params[:order_guide_id])
    # The guide itself was deactivated while the sheet was open. There is no
    # form to re-render against a guide that no longer exists, so this is the
    # one count-loss case we can't avoid — name it plainly instead of leaking
    # a RecordNotFound.
    if order_guide.nil?
      redirect_to new_inventory_count_path, alert: "That guide is no longer active. Pick an active guide to count."
      return
    end

    submitted_counts = submitted_count_values

    if submitted_counts.empty?
      rerender_empty_count(order_guide)
      return
    end

    parsed_counts, invalid_ids = parse_submitted_counts(submitted_counts)
    if invalid_ids.any?
      rerender_new_count(order_guide, submitted_counts, invalid_ids)
      return
    end

    memberships = order_guide.order_guide_memberships.active.counted.includes(:inventory_item).where(id: parsed_counts.keys)
    memberships_by_id = memberships.index_by { |membership| membership.id.to_s }

    # A row that was countable when the sheet loaded can stop being countable by
    # the time it's saved — another admin removes it from the guide or switches
    # it to order-only mid-count. Previously the fetch below raised KeyError, the
    # rescue redirected to the bare guide picker, and the whole count the user
    # walked the floor for was discarded. Treat it like any other recoverable
    # entry: re-render in place keeping every count, so nothing is thrown away.
    removed_ids = parsed_counts.keys - memberships_by_id.keys
    if removed_ids.any?
      rerender_removed_rows(order_guide, submitted_counts, removed_ids)
      return
    end

    inventory_count = nil
    ActiveRecord::Base.transaction do
      inventory_count = InventoryCount.create!(
        order_guide: order_guide,
        source: "manual",
        status: "completed",
        counted_at: Time.current,
        completed_at: Time.current,
        notes: params[:notes]
      )

      parsed_counts.each do |membership_id, quantity|
        membership = memberships_by_id.fetch(membership_id)
        inventory_count.inventory_count_lines.create!(
          order_guide_membership: membership,
          inventory_item: membership.inventory_item,
          quantity_on_hand: quantity,
          unit: membership.inventory_item.count_unit
        )
      end
    end

    redirect_to inventory_shopping_list_path(order_guide_id: order_guide.id), notice: "Saved #{inventory_count.inventory_count_lines.count} #{order_guide.name} counts."
  end

  def create_legacy_count
    submitted_counts = submitted_count_values

    if submitted_counts.empty?
      redirect_to new_inventory_count_path, alert: "Enter at least one count before saving."
      return
    end

    inventory_count = nil
    ActiveRecord::Base.transaction do
      inventory_count = InventoryCount.create!(
        source: "manual",
        status: "completed",
        counted_at: Time.current,
        completed_at: Time.current,
        notes: params[:notes]
      )

      submitted_counts.each do |item_id, value|
        item = InventoryItem.find(item_id)
        inventory_count.inventory_count_lines.create!(
          inventory_item: item,
          quantity_on_hand: BigDecimal(value.to_s),
          unit: item.count_unit
        )
      end
    end

    redirect_to inventory_counts_path, notice: "Saved #{inventory_count.inventory_count_lines.count} inventory counts."
  rescue ArgumentError, ActiveRecord::RecordInvalid
    # ArgumentError = a value that didn't parse; RecordInvalid = a value that
    # parsed but the count line rejects (e.g. a negative quantity). Either way,
    # surface a recoverable alert instead of crashing the save.
    redirect_to new_inventory_count_path, alert: "Each count must be a number of 0 or more."
  end

  def submitted_count_values
    raw_counts = params[:counts]
    count_values = raw_counts.respond_to?(:each_pair) ? raw_counts.each_pair.to_h : {}
    count_values.select { |_item_id, value| value.present? }
  end

  # Parse each submitted count into a number, separating any that aren't a valid
  # count. A value is invalid if it doesn't parse OR is negative — the count line
  # model rejects negatives (quantity_on_hand >= 0), so letting one through would
  # raise RecordInvalid in the transaction and crash the save to a generic error
  # page, discarding every count the user keyed in. Flagging it here routes it
  # through the same in-place re-render as an unparseable value, so the form
  # keeps the user's other counts and names the row to fix.
  def parse_submitted_counts(submitted_counts)
    parsed = {}
    invalid_ids = []
    submitted_counts.each do |membership_id, value|
      number = BigDecimal(value.to_s)
      raise ArgumentError if number.negative?

      parsed[membership_id.to_s] = number
    rescue ArgumentError
      invalid_ids << membership_id.to_s
    end
    [ parsed, invalid_ids ]
  end

  # Re-render the count form when nothing was entered, instead of redirecting to
  # a fresh form that silently drops the notes the user typed. Every other
  # recoverable problem on this form (bad number, negative, removed row) already
  # re-renders in place to keep the user's input; an empty submit is no
  # different — the guide is still active, so there is a form to keep, and the
  # notes are the one thing worth preserving. Surfaces the same "enter a count"
  # message inline (it persists in the form, unlike a flash) so the user can add
  # a count and save without retyping their note.
  def rerender_empty_count(order_guide)
    @order_guide = order_guide
    @order_guides = OrderGuide.active.ordered
    @memberships = counted_memberships_for(order_guide)
    @count_error = "Enter at least one count before saving."
    render :new_count, status: :unprocessable_entity
  end

  # Re-render the count form instead of redirecting, so one bad entry doesn't
  # discard every count the user keyed in. Repopulates the submitted values and
  # names the rows that still need a valid number.
  def rerender_new_count(order_guide, submitted_counts, invalid_ids)
    @order_guide = order_guide
    @order_guides = OrderGuide.active.ordered
    @memberships = counted_memberships_for(order_guide)
    @submitted_counts = submitted_counts.transform_keys(&:to_s)
    @invalid_count_ids = invalid_ids.to_set

    invalid_names = @memberships
      .select { |membership| @invalid_count_ids.include?(membership.id.to_s) }
      .map { |membership| membership.inventory_item.name }
    @count_error =
      if invalid_names.any?
        "Enter a count of 0 or more for #{invalid_names.to_sentence}. Your other counts are still here — fix these and save again."
      else
        "One of the counts was not a valid number."
      end

    render :new_count, status: :unprocessable_entity
  end

  # Re-render the count form when a submitted row is no longer countable (it was
  # removed from the guide or switched to order-only after the sheet loaded).
  # Keeps every count the user keyed in — the stale row simply no longer has a
  # field, so the next save records the rest — instead of discarding the whole
  # count and dropping the user back on the guide picker.
  def rerender_removed_rows(order_guide, submitted_counts, removed_ids)
    @order_guide = order_guide
    @order_guides = OrderGuide.active.ordered
    @memberships = counted_memberships_for(order_guide)
    @submitted_counts = submitted_counts.transform_keys(&:to_s)

    removed_names = OrderGuideMembership.where(id: removed_ids).includes(:inventory_item).map { |membership| membership.inventory_item.name }
    subject =
      if removed_names.any?
        removed_names.to_sentence
      elsif removed_ids.size == 1
        "A guide row"
      else
        "Some guide rows"
      end
    verb = removed_ids.size == 1 ? "was" : "were"
    @count_error = "#{subject} #{verb} removed from this guide while you were counting. Your other counts are still here — review and save again."

    render :new_count, status: :unprocessable_entity
  end

  def counted_memberships_for(order_guide)
    order_guide
      .order_guide_memberships
      .active
      .counted
      .includes(:order_guide_section, inventory_item: :product)
      .to_a
      .sort_by { |membership| membership_sort_key(membership) }
  end

  def count_line_sort_key(line)
    section = line.order_guide_membership&.order_guide_section
    [
      section&.position || 999_999,
      section&.name.to_s,
      line.inventory_item.name
    ]
  end

  def membership_sort_key(membership)
    section = membership.order_guide_section
    [
      section&.position || 999_999,
      section&.name.to_s,
      membership.position,
      membership.inventory_item.name
    ]
  end
end
