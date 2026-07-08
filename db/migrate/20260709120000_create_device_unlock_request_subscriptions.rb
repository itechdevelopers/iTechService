# frozen_string_literal: true

# Запоминаем, кого оператор выбрал в пикере при переходе «на согласование»
# (план §11 → расширение): после этого выбора любая активность по запросу
# (смена статуса, комментарии) уведомляет запомненных подписчиков + суперадминов.
# HABTM-таблица по образцу service_job_subscriptions.
class CreateDeviceUnlockRequestSubscriptions < ActiveRecord::Migration[5.1]
  def change
    # Короткие имена индексов заданы явно: авто-имена из длинного имени таблицы
    # превышают лимит идентификатора PostgreSQL (63 байта).
    create_table :device_unlock_request_subscriptions, id: false do |t|
      t.references :device_unlock_request, null: false,
                   index: { name: 'idx_dur_subscriptions_on_request' }
      t.references :subscriber, null: false,
                   index: { name: 'idx_dur_subscriptions_on_subscriber' }
    end
    add_index :device_unlock_request_subscriptions,
              %i[device_unlock_request_id subscriber_id],
              unique: true, name: 'idx_dur_subscriptions_unique'
  end
end
