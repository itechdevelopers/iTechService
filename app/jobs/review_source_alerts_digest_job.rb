# frozen_string_literal: true

# Суточное напоминание об открытых авариях сбора отзывов: одно сообщение со
# всем списком, а не по сообщению на аварию — когда ложится площадка целиком,
# лежат сразу все филиалы, и шесть сообщений вразнобой читать невозможно.
#
# Только Телеграм: запись в колокольчике появилась в момент открытия аварии и
# висит там, пока её не закроют, так что дублировать её ежедневно нечем.
# Телеграм, наоборот, уходит вверх ленты — по нему напоминание и нужно.
#
# Решает, когда звонить, Айс, а не агент: агент сообщает факты о состоянии
# источника, ответственность за людей и уведомления остаётся здесь.
class ReviewSourceAlertsDigestJob < ApplicationJob
  queue_as :default

  def perform
    text = ReviewSourceAlert.digest_telegram_text
    return if text.nil?

    User.superadmins.active.each do |recipient|
      NotifyEmployeeJob.perform_later(recipient.id, text)
    end
  end
end
