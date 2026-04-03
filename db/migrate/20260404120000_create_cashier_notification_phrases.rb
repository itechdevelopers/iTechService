class CreateCashierNotificationPhrases < ActiveRecord::Migration[5.1]
  def change
    create_table :cashier_notification_phrases do |t|
      t.string :text, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
  end
end
