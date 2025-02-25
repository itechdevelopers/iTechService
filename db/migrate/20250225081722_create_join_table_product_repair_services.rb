class CreateJoinTableProductRepairServices < ActiveRecord::Migration[5.1]
  def change
    create_join_table :products, :repair_services do |t|
      t.index [:product_id, :repair_service_id], unique: true, name: 'idx_products_repair_services_uniqueness'
      t.timestamps
    end
  end
end
