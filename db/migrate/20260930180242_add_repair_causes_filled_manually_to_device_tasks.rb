class AddRepairCausesFilledManuallyToDeviceTasks < ActiveRecord::Migration[5.1]
  def change
    add_column :device_tasks, :repair_causes_filled_manually, :boolean, default: false, null: false
  end
end
