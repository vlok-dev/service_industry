class AddWhatsappSentAtToJobs < ActiveRecord::Migration[7.0]
  def change
    add_column :jobs, :whatsapp_sent_at, :datetime
  end
end
