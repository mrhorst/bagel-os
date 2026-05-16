module Purchasing
  class InventoryRecommendation
    Row = Struct.new(:inventory_item, :quantity_on_hand, :buy_quantity, :status, keyword_init: true)

    def rows
      InventoryItem.active.ordered.includes(:inventory_section, :product, :inventory_count_lines).map do |item|
        quantity_on_hand = item.quantity_on_hand
        buy_quantity = buy_quantity_for(item, quantity_on_hand)

        Row.new(
          inventory_item: item,
          quantity_on_hand: quantity_on_hand,
          buy_quantity: buy_quantity,
          status: status_for(item, quantity_on_hand, buy_quantity)
        )
      end
    end

    def buy_now
      rows.select { |row| row.status == "buy_now" }
    end

    private

    def buy_quantity_for(item, quantity_on_hand)
      return nil if item.current_par.blank? || quantity_on_hand.blank?

      [ item.current_par.to_d - quantity_on_hand.to_d, 0 ].max
    end

    def status_for(item, quantity_on_hand, buy_quantity)
      return "not_counted" if quantity_on_hand.blank?
      return "buy_now" if buy_quantity.to_d.positive?
      return "near_reorder" if item.reorder_point.present? && quantity_on_hand.to_d <= item.reorder_point.to_d

      "ok"
    end
  end
end
