class CreateFindMyDeviceChecks < ActiveRecord::Migration[5.1]
  def change
    create_table :find_my_device_checks do |t|
      t.string :imei, null: false
      t.references :user, foreign_key: true, null: false
      t.references :service_job, foreign_key: true
      t.integer :status, null: false, default: 0
      t.string :api_response

      t.timestamps
    end

    add_index :find_my_device_checks, [:imei, :created_at]
  end
end
