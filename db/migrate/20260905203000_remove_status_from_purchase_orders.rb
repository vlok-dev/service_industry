class RemoveStatusFromPurchaseOrders < ActiveRecord::Migration[8.1]
  def change
    remove_column :purchase_orders, :status, :integer
  end
end
