module Purchasing
  class OrderGuideRecommendation
    Row = Struct.new(
      :membership,
      :inventory_item,
      :quantity_on_hand,
      :target_after_order,
      :buy_quantity,
      :status,
      keyword_init: true
    )

    def initialize(order_guide)
      @order_guide = order_guide
    end

    def rows
      memberships.map do |membership|
        quantity_on_hand = quantity_on_hand_for(membership)
        target_after_order = membership.target_after_order
        buy_quantity = buy_quantity_for(target_after_order, quantity_on_hand)

        Row.new(
          membership: membership,
          inventory_item: membership.inventory_item,
          quantity_on_hand: quantity_on_hand,
          target_after_order: target_after_order,
          buy_quantity: buy_quantity,
          status: status_for(membership, quantity_on_hand, buy_quantity)
        )
      end
    end

    def buy_now
      rows.select { |row| row.status == "buy_now" }
    end

    def not_counted
      rows.select { |row| row.status == "not_counted" }
    end

    def setup_needed
      rows.select { |row| row.status == "setup_needed" }
    end

    def order_only
      rows.select { |row| row.status == "order_only" }
    end

    private

    attr_reader :order_guide

    def memberships
      @memberships ||= order_guide
        .order_guide_memberships
        .active
        .includes(:order_guide_section, inventory_item: [ :product, :preferred_supplier ])
        .to_a
        .sort_by { |membership| membership_sort_key(membership) }
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

    def quantity_on_hand_for(membership)
      return nil if membership.order_only?

      membership.latest_count_line&.quantity_on_hand
    end

    def buy_quantity_for(target_after_order, quantity_on_hand)
      return nil if target_after_order.nil? || quantity_on_hand.nil?

      [ target_after_order.to_d - quantity_on_hand.to_d, 0 ].max
    end

    def status_for(membership, quantity_on_hand, buy_quantity)
      return "order_only" if membership.order_only?
      return "setup_needed" if membership.setup_needed?
      return "not_counted" if quantity_on_hand.nil?
      return "buy_now" if buy_quantity.to_d.positive?

      "ok"
    end
  end
end
