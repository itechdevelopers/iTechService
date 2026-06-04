# frozen_string_literal: true

# In-app уведомление о событии тестирования устройства. Параллельный канал к
# SendTestingTelegramNotificationJob: тот шлёт в общий Telegram-чат, этот
# создаёт персональные in-app Notification-записи получателям. ENV не нужен —
# работает и в dev (поэтому ручной тест виден прямо в браузере).
#
# Триггеры (ставятся после коммита транзакции, рядом с Telegram-вызовом):
#   отправка на тест → ServiceJobsController#update_repair_status
#   завершение теста → TestingsController#finish
class SendTestingInAppNotificationJob < ApplicationJob
  queue_as :default

  def perform(testing_session_id)
    session = TestingSession.find(testing_session_id)
    TestingInAppNotifier.call(session)
  end
end
