class AddReminderDismissedAtToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :reminder_dismissed_at, :datetime
  end
end