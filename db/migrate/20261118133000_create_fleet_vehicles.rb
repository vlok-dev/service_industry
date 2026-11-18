class CreateFleetVehicles < ActiveRecord::Migration[8.1]
  def change
    create_table :vehicles do |t|
      t.string :name, null: false
      t.string :registration_number
      t.string :plumber_name
      t.string :assistant_name
      t.integer :current_mileage
      t.date :last_service_date
      t.date :next_service_due_date
      t.text :last_service_notes
      t.date :registration_expiry

      t.timestamps
    end

    create_table :vehicle_tools do |t|
      t.references :vehicle, null: false, foreign_key: true
      t.string :name, null: false
      t.string :quantity
      t.boolean :signed_off, default: false, null: false
      t.string :signed_by
      t.date :signed_on
      t.text :notes

      t.timestamps
    end

    reversible do |dir|
      dir.up do
        now = Time.current.utc.strftime("%Y-%m-%d %H:%M:%S")
        1.upto(10) do |i|
          execute ActiveRecord::Base.send(:sanitize_sql_array, [
            "INSERT INTO vehicles (name, created_at, updated_at) VALUES (?, ?, ?)",
            "Vehicle #{i}", now, now
          ])
        end
      end
    end
  end
end
