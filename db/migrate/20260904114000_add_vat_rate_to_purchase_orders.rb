class AddVatRateToPurchaseOrders < ActiveRecord::Migration[8.1]
  def change
    add_column :purchase_orders, :vat_rate, :decimal, precision: 5, scale: 2, default: 15.0, null: false
  end
end