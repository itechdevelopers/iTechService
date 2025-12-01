class AddExpectedRepairFieldsToDeviceTasks < ActiveRecord::Migration[5.1]
  def change
    add_reference :device_tasks, :expected_repair_cause, foreign_key: { to_table: :repair_causes }, index: true
    add_reference :device_tasks, :expected_repair_service, foreign_key: { to_table: :repair_services }, index: true
  end
end
