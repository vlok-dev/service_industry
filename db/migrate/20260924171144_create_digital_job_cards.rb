class CreateDigitalJobCards < ActiveRecord::Migration[8.1]
  def change
    create_table :digital_job_cards do |t|
      t.string :client_name
      t.text :address
      t.date :date
      t.time :time_start
      t.time :time_finish
      t.text :description
      t.text :materials_used
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
