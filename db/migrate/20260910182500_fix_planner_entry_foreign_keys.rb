class FixPlannerEntryForeignKeys < ActiveRecord::Migration[7.0]
  def change
    drop_table :planner_entries if table_exists?(:planner_entries)

    create_table :planner_entries do |t|
      t.string :title, null: false
      t.text :description
      t.string :category, default: "other"
      t.date :entry_date, null: false
      t.time :entry_time
      t.references :assigned_to, class_name: "User", null: true, foreign_key: { to_table: :users }
      t.references :created_by, class_name: "User", null: false, foreign_key: { to_table: :users }
      t.string :status, default: "to_do"
      t.text :notes

      t.timestamps
    end

    add_index :planner_entries, :entry_date
    add_index :planner_entries, :category
    add_index :planner_entries, :status
  end
end