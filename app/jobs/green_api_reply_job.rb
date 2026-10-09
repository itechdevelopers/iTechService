# frozen_string_literal: true

# Реплика самой системы клиенту в канале GREEN-API — отказ на вложение,
# которое мы не умеем показать. Для ответов сотрудников есть
# SendClientMessageJob: у тех есть строка в ленте, и её судьбу надо показывать.
#
# Здесь показывать некому, поэтому неудача только пишется в лог: повторять
# отказ, пришедший с опозданием, смысла нет.
class GreenApiReplyJob < ApplicationJob
  queue_as :default

  def perform(channel, chat_id, text)
    outcome = GreenApi::SendMessage.call(channel: channel, chat_id: chat_id, text: text)
    return if outcome.success?

    Rails.logger.error("[GreenApiReplyJob] #{channel} chat #{chat_id}: #{outcome.result}")
  end
end
