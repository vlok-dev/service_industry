class AddInvoicedStatusToJobs < ActiveRecord::Migration[8.1]
  COMPLETED = 3
  INVOICED = 5

  # Invoiced used to be "completed + an invoice number", which meant an invoiced
  # job was simultaneously completed and invoiced. It now has its own status so
  # the pipeline stages are mutually exclusive.
  def up
    existing = select_value(<<~SQL.squish)
      SELECT COUNT(*) FROM jobs
      WHERE status = #{COMPLETED}
        AND invoice_number IS NOT NULL
        AND invoice_number <> ''
    SQL

    execute(<<~SQL.squish)
      UPDATE jobs
      SET status = #{INVOICED}
      WHERE status = #{COMPLETED}
        AND invoice_number IS NOT NULL
        AND invoice_number <> ''
    SQL

    # Keep the completion timestamp meaningful for anything that was already invoiced.
    execute(<<~SQL.squish)
      UPDATE jobs
      SET completed_at = #{quote(Time.current.utc)}
      WHERE status = #{INVOICED} AND completed_at IS NULL
    SQL

    say "Moved #{existing.to_i} completed job(s) to the invoiced status."
  end

  def down
    execute(<<~SQL.squish)
      UPDATE jobs SET status = #{COMPLETED} WHERE status = #{INVOICED}
    SQL
  end
end
