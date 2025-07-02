class AddArchivedToRepairServices < ActiveRecord::Migration[5.1]
  def change
    add_column :repair_services, :archived, :boolean, default: false, null: false
  end
end
