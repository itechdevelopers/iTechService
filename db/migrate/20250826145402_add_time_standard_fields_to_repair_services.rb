class AddTimeStandardFieldsToRepairServices < ActiveRecord::Migration[5.1]
  def change
    add_column :repair_services, :time_standard, :integer
    add_column :repair_services, :time_standard_from, :integer
    add_column :repair_services, :time_standard_to, :integer
  end
end
