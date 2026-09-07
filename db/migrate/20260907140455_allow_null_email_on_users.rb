class AllowNullEmailOnUsers < ActiveRecord::Migration[7.1]
  def up
    change_column_default :users, :email, from: "", to: nil
    change_column_null :users, :email, true
    execute "UPDATE users SET email = NULL WHERE email = ''"
  end

  def down
    execute "UPDATE users SET email = '' WHERE email IS NULL"
    change_column_null :users, :email, false
    change_column_default :users, :email, from: nil, to: ""
  end
end