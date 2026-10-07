# Чем закончился поиск номера в MAX. MAX ограничивает аккаунт за частые и
# особенно повторные проверки номера без аккаунта, поэтому запоминается и
# положительный ответ, и отрицательный.
class CreateMaxPhoneLookups < ActiveRecord::Migration[5.1]
  def change
    create_table :max_phone_lookups do |t|
      t.string :phone, null: false
      t.boolean :found, null: false, default: false
      t.string :chat_id
      t.string :max_name
      t.datetime :checked_at, null: false
      t.timestamps
    end
    add_index :max_phone_lookups, :phone, unique: true
  end
end
