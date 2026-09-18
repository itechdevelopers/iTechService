class MoveLegacyNotificationOptOuts < ActiveRecord::Migration[5.1]
  # Два точечных опт-аута жили отдельными колонками в user_settings; теперь то
  # же самое выражается персональной настройкой типа. Кто когда-то отписался,
  # должен остаться отписанным — иначе поток, от которого человек ушёл,
  # вернётся к нему после выката.
  MAPPING = {
    receive_location_task_notifications: 'service_job_location_added',
    receive_glass_sticking_notifications: 'glass_sticking'
  }.freeze

  def up
    MAPPING.each do |column, type_key|
      entry = NotificationCatalog[type_key]
      next if entry.nil?

      UserSettings.where(column => false).find_each do |settings|
        preference = UserNotificationPreference.find_or_initialize_by(
          user_id: settings.user_id, type_key: type_key
        )
        preference.assign_attributes(in_app: false, telegram: false,
                                     color: entry.default_color,
                                     bold: entry.default_bold)
        preference.save!
      end
    end
  end

  # Снимаем только те настройки, которые могла создать эта миграция: оба канала
  # выключены и ничего больше не менялось.
  def down
    UserNotificationPreference
      .where(type_key: MAPPING.values, in_app: false, telegram: false)
      .delete_all
  end
end
