class CreateUserNotificationPreferences < ActiveRecord::Migration[5.1]
  # Строка появляется только когда сотрудник что-то поменял: её отсутствие
  # означает «как в каталоге». Дефолты колонок совпадают с самыми частыми
  # значениями NotificationCatalog, но опорой служит именно каталог —
  # UserNotificationPreference.for отдаёт незаписанный объект с его значениями.
  def change
    create_table :user_notification_preferences do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :type_key, null: false
      t.boolean :in_app,   null: false, default: true
      t.boolean :telegram, null: false, default: true
      t.string  :color,    null: false, default: 'red'
      t.boolean :bold,     null: false, default: false
      t.integer :repeat_count,            null: false, default: 0
      t.integer :repeat_interval_minutes, null: false, default: 5

      t.timestamps
    end

    add_index :user_notification_preferences, %i[user_id type_key], unique: true,
              name: 'index_notification_preferences_on_user_and_type'
  end
end
