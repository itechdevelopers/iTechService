# frozen_string_literal: true

# Снимает индикатор с нажатой кнопки. Отдельно от MaxBotReplyJob: там адресат —
# чат, здесь — конкретное нажатие, и живёт оно недолго.
class MaxCallbackAnswerJob < ApplicationJob
  queue_as :default

  def perform(callback_id, notification = nil)
    outcome = AnswerMaxCallback.call(callback_id: callback_id, notification: notification)
    return if outcome.success?

    Rails.logger.error("[MaxCallbackAnswerJob] callback #{callback_id}: #{outcome.result}")
  end
end
