class RemoveMaterialsUsedFromDigitalJobCards < ActiveRecord::Migration[8.1]
  def change
    remove_column :digital_job_cards, :materials_used, :text
  end
end
