class AddInventoryImportFields < ActiveRecord::Migration[7.1]
  def change
    add_column :inventory_items, :stock_item_type, :string
    add_column :inventory_items, :total_stock_quantity, :decimal, precision: 12, scale: 2, default: 0
    add_column :inventory_items, :cost_price, :decimal, precision: 10, scale: 2
    add_column :inventory_items, :list_price, :decimal, precision: 10, scale: 2
    add_column :inventory_items, :replacement_percentage, :decimal, precision: 5, scale: 2
    add_column :inventory_items, :is_serializable, :boolean, default: false, null: false
    add_column :inventory_items, :is_quantity_tracked, :boolean, default: true, null: false
    add_column :inventory_items, :is_active, :boolean, default: true, null: false
    add_column :inventory_items, :created_by, :string
    add_column :inventory_items, :modified_by, :string
  end
end