class AddJobNumberAndInvoiceToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :job_number, :string
    add_column :jobs, :invoice_number, :string
  end
end
