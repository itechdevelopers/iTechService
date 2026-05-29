class AddGluingHoursToRepairStatusChanges < ActiveRecord::Migration[5.1]
  def change
    add_column :repair_status_changes, :gluing_hours, :integer
  end
end
