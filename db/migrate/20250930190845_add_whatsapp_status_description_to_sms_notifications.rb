class AddWhatsappStatusDescriptionToSmsNotifications < ActiveRecord::Migration[5.1]
  def change
    add_column :service_sms_notifications, :whatsapp_status_description, :text
    add_index :service_sms_notifications, :whatsapp_status
  end
end