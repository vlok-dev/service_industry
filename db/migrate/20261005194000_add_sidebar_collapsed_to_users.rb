class AddSidebarCollapsedToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :sidebar_collapsed, :boolean, default: false
  end
end