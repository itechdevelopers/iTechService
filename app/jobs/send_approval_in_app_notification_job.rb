# frozen_string_literal: true

# In-app уведомление о событии согласования. Параллельный канал к
# SendApprovalTelegramNotificationJob: тот шлёт в группу «Технарские
# уведомления», этот создаёт персональные Notification-записи. Настроек не
# требует — работает и в dev, и когда Telegram недоступен.
#
# Триггеры (ставятся после коммита транзакции, рядом с Telegram-вызовом):
#   создание запроса → ServiceJobsController#update_repair_status
#   ответ медиа      → ApprovalRequestsController#answer
class SendApprovalInAppNotificationJob < ApplicationJob
  queue_as :default

  def perform(approval_request_id)
    request = ApprovalRequest.find(approval_request_id)
    ApprovalInAppNotifier.call(request)
  end
end
