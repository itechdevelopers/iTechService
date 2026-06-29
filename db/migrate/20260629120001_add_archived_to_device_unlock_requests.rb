class AddArchivedToDeviceUnlockRequests < ActiveRecord::Migration[5.1]
  def change
    add_column :device_unlock_requests, :archived, :boolean, default: false, null: false
    add_index :device_unlock_requests, :archived
  end
end
