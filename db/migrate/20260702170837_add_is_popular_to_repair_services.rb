class AddIsPopularToRepairServices < ActiveRecord::Migration[5.1]
  def change
    add_column :repair_services, :is_popular, :boolean, default: false, null: false
  end
end
