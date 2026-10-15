class AddPauseUntilToRepairStatusChanges < ActiveRecord::Migration[5.1]
  def change
    add_column :repair_status_changes, :pause_until, :datetime
  end
end
