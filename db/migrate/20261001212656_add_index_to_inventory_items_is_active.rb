class AddIndexToInventoryItemsIsActive < ActiveRecord::Migration[8.1]
  def change
    add_index :inventory_items, :is_active
  end
end
