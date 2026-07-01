namespace :products do
  desc "Infer products.unit_basis from existing unit labels where it is unambiguous (idempotent)"
  task backfill_unit_basis: :environment do
    dimension_to_basis = {
      Measurement::Units::WEIGHT => "weight",
      Measurement::Units::VOLUME => "volume",
      Measurement::Units::COUNT => "count"
    }

    updated = 0
    skipped = 0

    # Only touch products that have no basis yet, so re-running never overwrites a
    # human decision. We infer from the comparable (standard) unit first, then the
    # package unit, and only when it maps cleanly to a known dimension.
    Product.where(unit_basis: [nil, ""]).find_each do |product|
      label = product.standard_unit.presence || product.unit_of_measure.presence
      dimension = Measurement::Units.dimension(label)
      basis = dimension && dimension_to_basis[dimension]

      if basis
        product.update_column(:unit_basis, basis)
        updated += 1
      else
        skipped += 1
      end
    end

    puts "Backfilled unit_basis on #{updated} product(s); left #{skipped} for manual review."
  end
end
