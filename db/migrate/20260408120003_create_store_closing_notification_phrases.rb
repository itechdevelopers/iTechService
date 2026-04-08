# frozen_string_literal: true

class CreateStoreClosingNotificationPhrases < ActiveRecord::Migration[5.1]
  def change
    create_table :store_closing_notification_phrases do |t|
      t.string :text, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
  end
end
