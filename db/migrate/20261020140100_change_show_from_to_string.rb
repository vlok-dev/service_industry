class ChangeShowFromToString < ActiveRecord::Migration[7.2]
  def change
    change_column :notifications, :show_from, :text
  end
end
