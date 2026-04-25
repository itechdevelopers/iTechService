class AddReceiveGlassStickingNotificationsToUserSettings < ActiveRecord::Migration[5.1]
  def change
    add_column :user_settings, :receive_glass_sticking_notifications, :boolean, default: true, null: false
  end
end
