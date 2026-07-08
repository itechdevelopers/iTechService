# frozen_string_literal: true

# Ежедневная проверка запросов на разблокировку «без движений» (план §13).
# Если по активному (не архивному) запросу STALE_AFTER (3 дня) нет активности
# (смена статуса или комментарий) — шлём in-app уведомление «связке»:
# подписчикам + суперадминам, а до прохождения пикера — только суперадминам
# (см. DeviceUnlockRequest#activity_recipients). Повторяем раз в 3 дня, пока
# запрос не уйдёт в архив. Cron — config/schedule.yml. Вся логика простоя/
# интервала — в модели (#notify_if_stale!); джоба лишь обходит кандидатов.
# Образец daily-джобы — ClientRequestPurchaseReminderJob.
class NotifyStaleUnlockRequestsJob < ApplicationJob
  queue_as :default

  def perform
    DeviceUnlockRequest.stale_candidates.find_each(&:notify_if_stale!)
  end
end
