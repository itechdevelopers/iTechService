class AddParticipatesInRepairServicesToDepartments < ActiveRecord::Migration[5.1]
  def change
    add_column :departments, :participates_in_repair_services, :boolean, default: true, null: false
  end
end
