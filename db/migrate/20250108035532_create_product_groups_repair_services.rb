class CreateProductGroupsRepairServices < ActiveRecord::Migration[5.1]
  def change
    create_table :product_groups_repair_services do |t|
      t.belongs_to :product_group, foreign_key: true, null: false
      t.belongs_to :repair_service, foreign_key: true, null: false

      t.timestamps
    end

    add_index :product_groups_repair_services,
              [:product_group_id, :repair_service_id],
              unique: true,
              name: 'index_pg_rs_on_pg_id_and_rs_id'
  end
end
