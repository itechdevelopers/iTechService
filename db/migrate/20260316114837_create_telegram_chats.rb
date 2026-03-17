class CreateTelegramChats < ActiveRecord::Migration[5.1]
  def change
    create_table :telegram_chats do |t|
      t.string :name, null: false
      t.string :chat_id, null: false

      t.timestamps
    end

    add_index :telegram_chats, :chat_id, unique: true
  end
end
