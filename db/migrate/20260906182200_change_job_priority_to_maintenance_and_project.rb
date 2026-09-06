class ChangeJobPriorityToMaintenanceAndProject < ActiveRecord::Migration[8.1]
  def up
    Job.where(priority: [0, 1]).update_all(priority: 0)
    Job.where(priority: [2, 3]).update_all(priority: 1)
  end

  def down
    Job.where(priority: 0).update_all(priority: 0)
    Job.where(priority: 1).update_all(priority: 2)
  end
end
