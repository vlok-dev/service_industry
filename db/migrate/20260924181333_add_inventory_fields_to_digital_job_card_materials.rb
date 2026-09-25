class AddInventoryFieldsToDigitalJobCardMaterials < ActiveRecord::Migration[8.1]
  def change
    add_reference :digital_job_card_materials, :inventory_item, null: true, foreign_key: true
    add_column :digital_job_card_materials, :markup, :decimal, precision: 5, scale: 2, default: 0
    add_column :digital_job_card_materials, :unit_price, :decimal, precision: 10, scale: 2, default: 0
    add_column :digital_job_card_materials, :labor_rate, :decimal, precision: 10, scale: 2, default: 0
    add_column :digital_job_card_materials, :total_price, :decimal, precision: 10, scale: 2, default: 0
    add_column :digital_job_card_materials, :is_labor, :boolean, default: false
  end
end
