class CreateDeviceUnlockRequests < ActiveRecord::Migration[5.1]
  def change
    create_table :device_unlock_requests do |t|
      t.references :client,     foreign_key: true, null: false
      t.references :item,       foreign_key: true, null: false
      t.references :user,       foreign_key: true, null: false
      t.references :department, foreign_key: true, null: false

      t.integer :status, null: false, default: 0
      t.text    :reason

      t.timestamps
    end
  end
end
