class AddWhatsappToSmsNotifications < ActiveRecord::Migration[5.1]
  def change
    add_column :service_sms_notifications, :message_type, :string, default: 'sms', null: false
    add_column :service_sms_notifications, :whatsapp_status, :string
    add_column :service_sms_notifications, :message_id, :string
    
    add_index :service_sms_notifications, :message_type
    add_index :service_sms_notifications, :message_id
  end
end
