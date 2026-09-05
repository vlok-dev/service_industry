class CreateInventoryItems < ActiveRecord::Migration[8.1]
  def change
    create_table :inventory_items do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.decimal :unit_price, precision: 10, scale: 2
      t.string :unit

      t.timestamps
    end
    add_index :inventory_items, :code, unique: true
  end
end
