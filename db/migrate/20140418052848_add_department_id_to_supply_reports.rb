class AddDepartmentIdToSupplyReports < ActiveRecord::Migration
  class SupplyReport < ActiveRecord::Base; end

  def change
    add_column :supply_reports, :department_id, :integer
    add_index :supply_reports, :department_id

    SupplyReport.unscoped.find_each do |r|
      r.update_column :department_id, Department.current.id
    end
  end
end
