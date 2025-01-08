class CreateProductGroupsRepairGroups < ActiveRecord::Migration[5.1]
  def up
    drop_table :product_groups_repair_services

    add_reference :product_groups, :repair_group, foreign_key: true
  end

  def down
    remove_column :product_groups, :repair_group
    create_table :product_groups_repair_services do |t|
      t.belongs_to :product_group, foreign_key: true, null: false
      t.belongs_to :repair_service, foreign_key: true, null: false

      t.timestamps
    end
  end
end
