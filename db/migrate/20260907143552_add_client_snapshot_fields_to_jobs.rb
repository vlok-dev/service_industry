class AddClientSnapshotFieldsToJobs < ActiveRecord::Migration[7.1]
  def change
    add_column :jobs, :customer_code, :string
    add_column :jobs, :contact_person, :string
    add_column :jobs, :email, :string
    add_column :jobs, :postal_address, :text
  end
end