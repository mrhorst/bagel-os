class BackfillOrderGuideSectionsFromInventorySections < ActiveRecord::Migration[8.1]
  class MigrationInventorySection < ActiveRecord::Base
    self.table_name = "inventory_sections"
  end

  class MigrationInventoryItem < ActiveRecord::Base
    self.table_name = "inventory_items"

    belongs_to :inventory_section, class_name: "BackfillOrderGuideSectionsFromInventorySections::MigrationInventorySection", optional: true
  end

  class MigrationOrderGuideMembership < ActiveRecord::Base
    self.table_name = "order_guide_memberships"

    belongs_to :inventory_item, class_name: "BackfillOrderGuideSectionsFromInventorySections::MigrationInventoryItem"
  end

  class MigrationOrderGuideSection < ActiveRecord::Base
    self.table_name = "order_guide_sections"

    def self.key_for(value)
      value.to_s.downcase.gsub(/&/, " and ").gsub(/[^a-z0-9]+/, " ").squish.parameterize
    end
  end

  def up
    memberships_without_sections.find_each do |membership|
      inventory_section = membership.inventory_item.inventory_section
      next if inventory_section.blank?

      section = MigrationOrderGuideSection.find_or_create_by!(
        order_guide_id: membership.order_guide_id,
        key: MigrationOrderGuideSection.key_for(inventory_section.name)
      ) do |order_guide_section|
        order_guide_section.name = inventory_section.name
        order_guide_section.position = inventory_section.position
        order_guide_section.active = true
      end

      membership.update_columns(order_guide_section_id: section.id, updated_at: Time.current)
    end
  end

  def down
    # Keep backfilled sections and memberships. Removing them would discard useful setup work.
  end

  private

  def memberships_without_sections
    MigrationOrderGuideMembership
      .where(order_guide_section_id: nil)
      .includes(inventory_item: :inventory_section)
  end
end
