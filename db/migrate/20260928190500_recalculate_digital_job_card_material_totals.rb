class RecalculateDigitalJobCardMaterialTotals < ActiveRecord::Migration[7.1]
  def up
    skipped = []
    updated = 0

    DigitalJobCardMaterial.find_each do |material|
      # A row is only safe to restate when it does not carry both material and
      # labour figures. Mixed rows came from the old form, which priced them as
      # one blended number, so they need a human call and keep their stored total.
      if material.is_labor?
        material_cost = material.unit_price.to_d * material.quantity.to_d * (1 + material.markup.to_d / 100)
        if material_cost.positive?
          skipped << material.id
          next
        end
        total = (material.labor_rate.to_d * material.hours_worked.to_d).round(2)
      else
        if material.labor_rate.to_d.positive?
          skipped << material.id
          next
        end
        total = (material.unit_price.to_d * material.quantity.to_d * (1 + material.markup.to_d / 100)).round(2)
      end

      next if material.total_price == total

      material.update_columns(total_price: total)
      updated += 1
    end

    say "Restated #{updated} digital job card line total(s)."
    say "Mixed material + labour rows left untouched for review: #{skipped.inspect}" if skipped.any?
  end

  def down
    say "Stored totals are derived values and are not reverted."
  end
end
