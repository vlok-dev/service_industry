class AddClientRefToJobs < ActiveRecord::Migration[8.1]
  def change
    add_reference :jobs, :client, null: true, foreign_key: true
  end
end
