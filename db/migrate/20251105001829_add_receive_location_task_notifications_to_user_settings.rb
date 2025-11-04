class AddReceiveLocationTaskNotificationsToUserSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :user_settings, :receive_location_task_notifications, :boolean, default: true, null: false
  end
end
