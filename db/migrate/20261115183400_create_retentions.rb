class CreateRetentions < ActiveRecord::Migration[8.1]
  def change
    create_table :retentions do |t|
      t.integer "client_id"
      t.string "client_name"
      t.string "project_name", null: false
      t.date "date_held", null: false
      t.decimal "amount", precision: 12, scale: 2, null: false
      t.string "invoice_number"
      t.date "release_date", null: false
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["client_id"], name: "index_retentions_on_client_id"
      t.index ["release_date"], name: "index_retentions_on_release_date"
    end
    add_foreign_key "retentions", "clients"
  end
end
