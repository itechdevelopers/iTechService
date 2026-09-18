class AddNotificationSettingsColumns < ActiveRecord::Migration[5.1]
  # type_key — стабильный ключ типа уведомления из NotificationCatalog.
  # Отдельно от kind, потому что у того есть вторая роль — ключ дедупликации
  # с параметрами повода внутри (location_overstay_7_loc_42), и на один тип
  # там приходится столько значений, сколько порогов и локаций.
  #
  # hidden_at — запись создана, но в колокольчик не показывается: сотрудник
  # отключил себе этот канал. Не создавать её вовсе нельзя — на
  # Notification.exists? держится защита от дублей в восьми джобах, а повторам
  # нужна точка остановки (closed_at).
  #
  # repeats_sent — сколько повторов уже ушло; ограничивает их число.
  def change
    add_column :notifications, :type_key, :string
    add_column :notifications, :hidden_at, :datetime
    add_column :notifications, :repeats_sent, :integer, default: 0, null: false

    add_index :notifications, :type_key
  end
end
