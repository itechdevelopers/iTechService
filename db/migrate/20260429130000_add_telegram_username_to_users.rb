class AddTelegramUsernameToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :telegram_username, :string
  end
end
