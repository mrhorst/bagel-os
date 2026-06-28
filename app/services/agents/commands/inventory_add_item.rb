module Agents
  module Commands
    # Add an inventory item. The item's key is derived from the name
    # automatically (InventoryItem#assign_key). A --section is matched by name
    # and created if it doesn't exist yet, so authoring stays one step.
    #
    # Per the project rule, units and pack sizes are NOT guessed — they're only
    # set when you pass them explicitly.
    class InventoryAddItem < Command
      command "inventory:add-item"
      summary "Add an inventory item"
      mutates!
      usage(
        "Usage: bin/agent inventory:add-item --name \"Cream cheese\" --section \"Walk-in\"",
        "",
        "Options:",
        "  --name <text>          Item name (required)",
        "  --section <name>       Inventory section (created if new)",
        "  --guide-frequency <f>  manual | weekly | monthly | both (default manual)",
        "  --category <text>      Category label",
        "  --count-unit <text>    Unit counted in (e.g. case, lb) — not guessed",
        "  --pack-size <text>     Pack size text — not guessed",
        "  --par <n>              Current par level",
        "  --notes <text>         Optional notes",
        "  --dry-run              Report what would be created without writing"
      )
      param :name, required: true, desc: "Item name"
      param :section, desc: "Inventory section (created if new)"
      param :"guide-frequency", desc: "manual | weekly | monthly | both (default manual)"
      param :category, desc: "Category label"
      param :"count-unit", desc: "Unit counted in (not guessed)"
      param :"pack-size", desc: "Pack size text (not guessed)"
      param :par, type: "integer", desc: "Current par level"
      param :notes, desc: "Optional notes"
      param :"dry-run", type: "boolean", desc: "Report what would be created without writing"

      def call
        name = options.value("name")
        raise UsageError, "Provide --name" if name.blank?

        section_name = options.value("section").presence
        guide_frequency = options.value("guide-frequency", "manual")

        if options.flag?("dry-run")
          return {
            dry_run: true,
            would: "create_inventory_item",
            name: name,
            section: section_name,
            section_exists: section_name ? InventorySection.exists?(["LOWER(name) = ?", section_name.downcase]) : nil,
            guide_frequency: guide_frequency
          }
        end

        section = resolve_or_create_section(section_name)
        item = InventoryItem.create!(
          name: name,
          inventory_section: section,
          guide_frequency: guide_frequency,
          category: options.value("category"),
          count_unit: options.value("count-unit"),
          pack_size: options.value("pack-size"),
          current_par: options.value("par"),
          notes: options.value("notes")
        )

        {
          created: true,
          inventory_item: {
            id: item.id,
            name: item.name,
            key: item.key,
            section: section&.name,
            guide_frequency: item.guide_frequency
          }
        }
      rescue ActiveRecord::RecordInvalid => e
        raise UsageError, e.message
      end

      private

      def resolve_or_create_section(name)
        return nil if name.blank?

        InventorySection.where("LOWER(name) = ?", name.downcase).first ||
          InventorySection.create!(name: name)
      end
    end
  end
end
