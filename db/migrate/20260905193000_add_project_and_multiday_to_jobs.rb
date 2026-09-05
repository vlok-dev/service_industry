class AddProjectAndMultidayToJobs < ActiveRecord::Migration[8.1]
  def change
    add_column :jobs, :is_project, :boolean, default: false, null: false
    add_column :jobs, :scheduled_end_date, :date
    add_index :jobs, :is_project
  end
end
