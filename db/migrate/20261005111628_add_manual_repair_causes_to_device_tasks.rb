class AddManualRepairCausesToDeviceTasks < ActiveRecord::Migration[5.1]
  def change
    add_column :device_tasks, :manual_repair_causes, :text
  end
end
