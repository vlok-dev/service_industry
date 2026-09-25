class AddJobIdToDigitalJobCards < ActiveRecord::Migration[8.1]
  def change
    add_reference :digital_job_cards, :job, null: true, foreign_key: true
  end
end
