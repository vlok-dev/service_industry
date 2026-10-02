class CreateQuotesAndQuoteItems < ActiveRecord::Migration[8.1]
  def change
    create_table :quotes do |t|
      t.string :quote_number, null: false
      t.integer :job_id, null: false
      t.integer :created_by_id
      t.decimal :vat_rate, precision: 5, scale: 2, default: "15.0", null: false
      t.text :notes
      t.text :terms
      t.date :valid_until
      t.timestamps
      t.index ["job_id"], name: "index_quotes_on_job_id"
      t.index ["quote_number"], name: "index_quotes_on_quote_number", unique: true
      t.index ["created_by_id"], name: "index_quotes_on_created_by_id"
    end

    create_table :quote_items do |t|
      t.integer :quote_id, null: false
      t.string :code
      t.text :description
      t.decimal :quantity, precision: 12, scale: 4, default: "0.0", null: false
      t.decimal :unit_price, precision: 10, scale: 2, default: "0.0", null: false
      t.decimal :total_price, precision: 10, scale: 2, default: "0.0", null: false
      t.integer :inventory_item_id
      t.timestamps
      t.index ["quote_id"], name: "index_quote_items_on_quote_id"
      t.index ["inventory_item_id"], name: "index_quote_items_on_inventory_item_id"
    end

    add_foreign_key :quotes, :jobs
    add_foreign_key :quotes, :users, column: :created_by_id
    add_foreign_key :quote_items, :quotes
    add_foreign_key :quote_items, :inventory_items
  end
end