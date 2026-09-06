class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.string :name, null: false
      t.text :address
      t.string :contact_person
      t.string :phone_number
      t.string :email

      t.timestamps
    end
    add_index :clients, :name
  end
end
