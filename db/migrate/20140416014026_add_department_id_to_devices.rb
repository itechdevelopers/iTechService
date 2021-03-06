class AddDepartmentIdToDevices < ActiveRecord::Migration
  class Device < ActiveRecord::Base;end

  def change
    add_column :devices, :department_id, :integer
    add_index :devices, :department_id

    Device.unscoped.find_each do |device|
      device.update_column :department_id, Department.current.id
    end
  end
end
