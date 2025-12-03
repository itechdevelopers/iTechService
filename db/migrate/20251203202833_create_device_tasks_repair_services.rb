class CreateDeviceTasksRepairServices < ActiveRecord::Migration[5.1]
  def change
    create_join_table :device_tasks, :repair_services do |t|
      t.index [:device_task_id, :repair_service_id], name: 'idx_dt_rs_on_device_task_and_service'
      t.index [:repair_service_id, :device_task_id], name: 'idx_dt_rs_on_service_and_device_task'
    end
  end
end
