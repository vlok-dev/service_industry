class CreateNotifications < ActiveRecord::Migration[7.2]
  def change
    create_table :notifications do |t|
      t.string :title
      t.text :description
      t.string :image_url
      t.date :release_date
      t.date :show_from
      t.timestamps
    end
    create_table :notification_dismissals do |t|
      t.references :user, null: false, foreign_key: true
      t.references :notification, null: false, foreign_key: true
      t.timestamps
    end
    add_index :notification_dismissals, [:user_id, :notification_id], unique: true
  end
end
