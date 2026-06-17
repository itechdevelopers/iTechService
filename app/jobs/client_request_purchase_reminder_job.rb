# frozen_string_literal: true

# Ежедневное напоминание по запросам, где покупка не подтверждена, а workflow
# ещё открыт (не done/failed). Шлёт уведомление получателям, пока сотрудники не
# подтвердят покупку либо не закроют запрос. Cron — config/schedule.yml.
# Образец daily-джобы — BadReviewAnnouncementsJob.
class ClientRequestPurchaseReminderJob < ApplicationJob
  queue_as :default

  def perform
    ClientRequest.awaiting_purchase_followup.find_each do |request|
      ClientRequestNotifier.notify_unconfirmed(request)
    end
  end
end
