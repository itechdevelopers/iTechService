class AddDisableDeadlineNotificationsToClients < ActiveRecord::Migration[5.1]
  def change
    add_column :clients, :disable_deadline_notifications, :boolean, default: false
  end
end
