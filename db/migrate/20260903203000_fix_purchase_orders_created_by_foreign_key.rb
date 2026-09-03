class FixPurchaseOrdersCreatedByForeignKey < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :purchase_orders, column: :created_by_id if foreign_key_exists?(:purchase_orders, column: :created_by_id)
    add_foreign_key :purchase_orders, :users, column: :created_by_id unless foreign_key_exists?(:purchase_orders, :users, column: :created_by_id)
  end

  def down
    remove_foreign_key :purchase_orders, column: :created_by_id if foreign_key_exists?(:purchase_orders, column: :created_by_id)
  end
end
