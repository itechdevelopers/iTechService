class CreateUserRepairCapabilities < ActiveRecord::Migration[5.1]
  def change
    create_table :user_repair_capabilities do |t|
      t.references :user, foreign_key: true, null: false
      t.references :repair_service, foreign_key: true, null: false
      t.text :comment

      t.timestamps
    end

    add_index :user_repair_capabilities, %i[user_id repair_service_id], unique: true, name: 'index_user_repair_capabilities_unique'
  end
end
