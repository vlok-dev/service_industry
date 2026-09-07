class AddContactNumberToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :contact_number, :string
  end
end
