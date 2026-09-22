class ChangeQuantityOnPurchaseOrderItemsToDecimal < ActiveRecord::Migration[8.1]
  def change
    change_column :purchase_order_items, :quantity, :decimal, precision: 12, scale: 4
  end
end
