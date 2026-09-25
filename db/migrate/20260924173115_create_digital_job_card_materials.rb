class CreateDigitalJobCardMaterials < ActiveRecord::Migration[8.1]
  def change
    create_table :digital_job_card_materials do |t|
      t.references :digital_job_card, null: false, foreign_key: true
      t.string :material_name
      t.decimal :quantity, precision: 10, scale: 4, default: 0.0

      t.timestamps
    end
  end
end
