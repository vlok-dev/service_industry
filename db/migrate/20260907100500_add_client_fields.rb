class AddClientFields < ActiveRecord::Migration[8.1]
  def change
    add_column :clients, :customer_code, :string
    add_column :clients, :delivery_address, :text
    add_column :clients, :postal_address, :text
    add_column :clients, :primary_contact_mobile, :string
    add_index :clients, :customer_code
  end
end
