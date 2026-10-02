class AddQuoteDateToQuotes < ActiveRecord::Migration[8.1]
  def change
    add_column :quotes, :quote_date, :date
  end
end
