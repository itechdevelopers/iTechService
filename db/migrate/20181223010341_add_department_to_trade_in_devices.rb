class AddDepartmentToTradeInDevices < ActiveRecord::Migration
  class TradeInDevice < ActiveRecord::Base; end

  def change
    add_reference :trade_in_devices, :department, index: true, foreign_key: true

    reversible do |dir|
      dir.up do
        default_department_id = Department.select(:id).find_by(code: ENV.fetch('DEPARTMENT_CODE', 'vl'))&.id

        TradeInDevice.where(department_id: nil).find_each do |device|
          device.update_column(:department_id, default_department_id)
        end

        change_column_null :trade_in_devices, :department_id, false
      end
    end
  end
end
