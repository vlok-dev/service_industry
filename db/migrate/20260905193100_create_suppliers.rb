class CreateSuppliers < ActiveRecord::Migration[8.1]
  def change
    create_table :suppliers do |t|
      t.string :name, null: false
      t.string :contact_person
      t.string :phone
      t.string :email
      t.text :address

      t.timestamps
    end
    add_index :suppliers, :name
  end
end
