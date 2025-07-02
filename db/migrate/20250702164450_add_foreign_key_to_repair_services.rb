class AddForeignKeyToRepairServices < ActiveRecord::Migration[5.1]
  def change
    add_foreign_key :repair_services, :repair_groups
  end
end
