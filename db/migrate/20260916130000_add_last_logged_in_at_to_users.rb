class AddLastLoggedInAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_logged_in_at, :datetime
    add_index :users, :last_logged_in_at
  end
end
