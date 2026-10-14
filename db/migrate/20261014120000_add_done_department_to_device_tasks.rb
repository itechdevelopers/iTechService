class AddDoneDepartmentToDeviceTasks < ActiveRecord::Migration[5.1]
  def change
    add_reference :device_tasks, :done_department, foreign_key: { to_table: :departments }, index: false
    add_index :device_tasks, %i[done_department_id done_at]
  end
end
