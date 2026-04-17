class CreateCheckListsRepairServices < ActiveRecord::Migration[5.1]
  def change
    create_join_table :check_lists, :repair_services do |t|
      t.index [:check_list_id, :repair_service_id], unique: true, name: 'idx_check_lists_repair_services'
      t.index [:repair_service_id, :check_list_id], name: 'idx_repair_services_check_lists'
    end
  end
end
