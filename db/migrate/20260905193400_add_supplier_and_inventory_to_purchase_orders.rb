class AddSupplierAndInventoryToPurchaseOrders < ActiveRecord::Migration[8.1]
  def change
    add_reference :purchase_orders, :supplier, foreign_key: true
    add_reference :purchase_order_items, :inventory_item, foreign_key: { to_table: :inventory_items }
    add_column :purchase_order_items, :code, :string
  end
end
