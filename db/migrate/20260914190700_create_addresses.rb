class CreateAddresses < ActiveRecord::Migration[7.1]
  def change
    create_table :addresses do |t|
      t.references :client, null: false, foreign_key: true
      t.string :label, default: "Other"
      t.text :address
      t.boolean :is_default, default: false

      t.timestamps
    end
  end
end
