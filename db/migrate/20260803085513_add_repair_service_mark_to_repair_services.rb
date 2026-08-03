class AddRepairServiceMarkToRepairServices < ActiveRecord::Migration[5.1]
  def change
    add_reference :repair_services, :repair_service_mark, foreign_key: true
  end
end
