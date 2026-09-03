class CreatePurchaseOrderItems < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_order_items do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.string :description
      t.integer :quantity
      t.decimal :unit_price
      t.decimal :total

      t.timestamps
    end
  end
end
