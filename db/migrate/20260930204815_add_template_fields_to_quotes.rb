class AddTemplateFieldsToQuotes < ActiveRecord::Migration[8.1]
  def change
    add_column :quotes, :company, :string
    add_column :quotes, :attention, :string
    add_column :quotes, :email_address, :string
    add_column :quotes, :property, :string
    add_column :quotes, :subject, :string
  end
end
