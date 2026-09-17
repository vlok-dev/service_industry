class CreateReports < ActiveRecord::Migration[8.1]
  def change
    create_table :reports do |t|
      t.integer :category, null: false
      t.string :title, null: false
      t.text :description
      t.string :role, null: false
      t.integer :status, null: false, default: 0
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
