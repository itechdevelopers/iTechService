# frozen_string_literal: true

# «Устройство N дней без движений» (план §13). Храним только момент последней
# stale-рассылки — чтобы соблюдать интервал «раз в 3 дня» и не слать ежедневно.
# Сама «последняя активность» НЕ хранится: она вычисляется как
# max(updated_at, comments.max(created_at)) — см. DeviceUnlockRequest#last_activity_at.
# Пишется через update_column, поэтому НЕ бампает updated_at (иначе рассылка
# сама сбросила бы таймер активности).
class AddStaleNotifiedAtToDeviceUnlockRequests < ActiveRecord::Migration[5.1]
  def change
    add_column :device_unlock_requests, :stale_notified_at, :datetime
  end
end
