class AddWhatsappSentAtToPlannerEntries < ActiveRecord::Migration[7.0]
  def change
    add_column :planner_entries, :whatsapp_sent_at, :datetime
  end
end
