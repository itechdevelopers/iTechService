class CreateDutyNotificationPhrases < ActiveRecord::Migration[5.1]
  def change
    create_table :duty_notification_phrases do |t|
      t.string :text, null: false
      t.boolean :active, default: true

      t.timestamps
    end
  end
end
