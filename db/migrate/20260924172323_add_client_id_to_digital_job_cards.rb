class AddClientIdToDigitalJobCards < ActiveRecord::Migration[8.1]
  def change
    add_column :digital_job_cards, :client_id, :integer
    add_foreign_key :digital_job_cards, :clients
    add_index :digital_job_cards, :client_id
  end
end
