class AddCustomShiftToScheduleEntries < ActiveRecord::Migration[5.1]
  def change
    add_column :schedule_entries, :custom_start_time, :time
    add_column :schedule_entries, :custom_end_time, :time
  end
end
