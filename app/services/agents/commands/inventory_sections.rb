module Agents
  module Commands
    # Inventory sections (shelf/area groupings) you can file items under.
    class InventorySections < Command
      command "inventory:sections"
      summary "Inventory sections, with how many active items each holds"

      def call
        sections = InventorySection.ordered.left_joins(:inventory_items)
          .select("inventory_sections.*, COUNT(CASE WHEN inventory_items.active THEN 1 END) AS active_item_count")
          .group("inventory_sections.id")

        {
          count: sections.length,
          sections: sections.map { |s| { id: s.id, name: s.name, active_item_count: s.active_item_count.to_i } }
        }
      end
    end
  end
end
