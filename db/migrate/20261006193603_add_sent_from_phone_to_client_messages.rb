# Ответ, набранный прямо в мессенджере на телефоне канала, а не в Айсе: у
# него нет автора, но клиенту он ушёл, и диалог после него отвечен.
class AddSentFromPhoneToClientMessages < ActiveRecord::Migration[5.1]
  def change
    add_column :client_messages, :sent_from_phone, :boolean, default: false, null: false
  end
end
