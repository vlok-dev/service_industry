class AddHoursWorkedToDigitalJobCardMaterials < ActiveRecord::Migration[8.1]
  # hours_worked appears in schema.rb but was never added by a migration, so
  # databases migrated from scratch (production) are missing it. It is required
  # now that labour lines are costed as hours x rate.
  def up
    return if column_exists?(:digital_job_card_materials, :hours_worked)

    add_column :digital_job_card_materials, :hours_worked, :decimal, default: 1.0, null: false
  end

  def down
    return unless column_exists?(:digital_job_card_materials, :hours_worked)

    remove_column :digital_job_card_materials, :hours_worked
  end
end
