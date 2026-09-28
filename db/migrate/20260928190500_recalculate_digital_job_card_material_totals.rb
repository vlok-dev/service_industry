class RecalculateDigitalJobCardMaterialTotals < ActiveRecord::Migration[7.1]
  COLUMNS = %w[id is_labor unit_price quantity markup labor_rate hours_worked total_price].freeze

  # total_price is numeric(10,2); writing past this raises on Postgres, which
  # would fail the deploy, so out-of-range rows are reported instead.
  MAX_TOTAL = BigDecimal("99999999.99")

  def up
    rows = select_rows("SELECT #{COLUMNS.join(', ')} FROM digital_job_card_materials")
    updated = 0
    skipped = []

    rows.each do |row|
      attrs = COLUMNS.zip(row).to_h
      total = restated_total(attrs)

      if total.nil?
        skipped << attrs["id"]
        next
      end

      next if decimal(attrs["total_price"]) == total

      execute(
        "UPDATE digital_job_card_materials SET total_price = #{total.to_s('F')} WHERE id = #{attrs['id'].to_i}"
      )
      updated += 1
    end

    say "Restated #{updated} digital job card line total(s)."
    say "Mixed material + labour rows left untouched for review: #{skipped.sort.inspect}" if skipped.any?
  end

  def down
    say "Stored totals are derived values and are not reverted."
  end

  private

  # Returns the corrected total, or nil when the row cannot be restated safely:
  # either it carries both material and labour figures (the old form priced it as
  # one blended number, so only a human can say how it should split), or the
  # restated figure does not fit the column.
  def restated_total(attrs)
    labor = truthy?(attrs["is_labor"])
    unit_price = decimal(attrs["unit_price"])
    quantity = decimal(attrs["quantity"])
    markup = decimal(attrs["markup"])
    labor_rate = decimal(attrs["labor_rate"])
    hours = decimal(attrs["hours_worked"])

    material_cost = unit_price * quantity * (1 + markup / 100)

    if labor
      return nil if material_cost > 0
      total = (labor_rate * hours).round(2)
    else
      return nil if labor_rate > 0
      total = material_cost.round(2)
    end

    return nil if total.negative? || total > MAX_TOTAL

    total
  end

  def decimal(value)
    return BigDecimal("0") if value.nil?

    BigDecimal(value.to_s)
  rescue ArgumentError, TypeError
    BigDecimal("0")
  end

  def truthy?(value)
    value == true || value.to_s == "t" || value.to_s == "1"
  end
end
