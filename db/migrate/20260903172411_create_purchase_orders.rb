class CreatePurchaseOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :purchase_orders do |t|
      t.references :job, null: false, foreign_key: true
      t.string :po_number
      t.string :supplier_name
      t.string :supplier_contact
      t.integer :status
      t.date :order_date
      t.date :expected_delivery
      t.decimal :total_amount
      t.text :notes
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
