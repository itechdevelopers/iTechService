class AddArchivedToRepairGroups < ActiveRecord::Migration[5.1]
  def change
    add_column :repair_groups, :archived, :boolean, default: false, null: false
    add_index :repair_groups, :archived
  end
end
