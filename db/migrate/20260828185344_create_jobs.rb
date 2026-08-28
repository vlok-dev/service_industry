class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.string :customer_name
      t.text :address
      t.text :description
      t.date :scheduled_date
      t.time :scheduled_time
      t.integer :status
      t.integer :priority
      t.references :assigned_to, foreign_key: { to_table: :users }
      t.text :notes
      t.datetime :completed_at
      t.datetime :cancelled_at
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
