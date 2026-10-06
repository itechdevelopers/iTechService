# frozen_string_literal: true

# Реплика самой системы клиенту в MAX по номеру — отказ на вложение, которое
# мы не умеем показать. Для ответов сотрудников есть SendClientMessageJob: у
# тех есть строка в ленте, и её судьбу надо показывать.
#
# Здесь показывать некому, поэтому неудача только пишется в лог: повторять
# отказ, пришедший с опозданием, смысла нет.
class MaxPhoneReplyJob < ApplicationJob
  queue_as :default

  def perform(chat_id, text)
    outcome = SendMaxPhoneMessage.call(chat_id: chat_id, text: text)
    return if outcome.success?

    Rails.logger.error("[MaxPhoneReplyJob] chat #{chat_id}: #{outcome.result}")
  end
end
