class AddDeletionTogglesToSettings < ActiveRecord::Migration[7.1]
  def change
    add_column :settings, :allow_client_deletion, :boolean, default: true
    add_column :settings, :allow_supplier_deletion, :boolean, default: true
    add_column :settings, :allow_inventory_deletion, :boolean, default: true
  end
end