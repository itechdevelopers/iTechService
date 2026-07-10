# frozen_string_literal: true

class AddTelegramLinkingToUsers < ActiveRecord::Migration[5.1]
  def change
    add_column :users, :telegram_chat_id, :bigint
    add_column :users, :telegram_link_token, :string

    add_index :users, :telegram_link_token, unique: true
  end
end
