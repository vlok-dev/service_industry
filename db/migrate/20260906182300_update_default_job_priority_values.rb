class UpdateDefaultJobPriorityValues < ActiveRecord::Migration[8.1]
  def up
    Setting.where(default_job_priority: ["low", "medium"]).update_all(default_job_priority: "maintenance")
    Setting.where(default_job_priority: ["high", "emergency"]).update_all(default_job_priority: "project")
  end

  def down
    Setting.where(default_job_priority: "maintenance").update_all(default_job_priority: "medium")
    Setting.where(default_job_priority: "project").update_all(default_job_priority: "high")
  end
end
