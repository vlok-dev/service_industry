class CreateClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :claims do |t|
      t.references :job, null: false, foreign_key: true
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :claim_date, null: false
      t.integer :status, default: 0, null: false
      t.string :reference
      t.text :description

      t.timestamps
    end
    add_index :claims, :status
  end
end
