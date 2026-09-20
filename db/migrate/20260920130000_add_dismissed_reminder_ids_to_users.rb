class AddDismissedReminderIdsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :dismissed_reminder_ids_raw, :text
  end
end