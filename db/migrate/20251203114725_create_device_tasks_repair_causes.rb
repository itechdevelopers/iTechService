class CreateDeviceTasksRepairCauses < ActiveRecord::Migration[5.1]
  def change
    create_join_table :device_tasks, :repair_causes do |t|
      t.index [:device_task_id, :repair_cause_id], name: 'idx_dt_rc_on_device_task_and_cause'
      t.index [:repair_cause_id, :device_task_id], name: 'idx_dt_rc_on_cause_and_device_task'
    end
  end
end
