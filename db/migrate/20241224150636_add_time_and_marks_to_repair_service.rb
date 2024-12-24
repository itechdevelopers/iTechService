class AddTimeAndMarksToRepairService < ActiveRecord::Migration[5.1]
  def change
    add_column :repair_services, :repair_time, :integer
    add_column :repair_services, :special_marks, :text
  end
end
