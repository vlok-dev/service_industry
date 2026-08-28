class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.string :company_name
      t.string :whatsapp_api_key
      t.string :whatsapp_phone_id
      t.string :default_job_priority
      t.time :working_hours_start
      t.time :working_hours_end
      t.string :notification_email

      t.timestamps
    end
  end
end
