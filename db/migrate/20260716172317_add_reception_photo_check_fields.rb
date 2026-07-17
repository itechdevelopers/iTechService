class AddReceptionPhotoCheckFields < ActiveRecord::Migration[5.1]
  def change
    # Флаг задачи: приёмка с такой задачей обязана иметь фото при приёмке.
    add_column :tasks, :require_reception_photo, :boolean, default: false, null: false

    # Guard-таймстамп: момент, когда для работы уже поставлена одноразовая
    # проверка фото. Не NULL → повторные редактирования её не перезапускают
    # (семантика «запустить один раз»).
    add_column :service_jobs, :reception_photo_check_scheduled_at, :datetime
  end
end
