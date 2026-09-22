# frozen_string_literal: true

# Реплика самого бота — приветствие на старте и прочие служебные ответы,
# которых нет в ленте диалога. Для ответов сотрудников есть
# SendClientMessageJob: у тех есть строка в базе, и её судьбу надо показывать.
#
# Здесь показывать некому, поэтому неудача только пишется в лог: повторять
# приветствие, пришедшее с опозданием в минуту, смысла нет.
class MaxBotReplyJob < ApplicationJob
  queue_as :default

  def perform(chat_id, text)
    outcome = SendMaxMessage.call(chat_id: chat_id, text: text)
    return if outcome.success?

    Rails.logger.error("[MaxBotReplyJob] chat #{chat_id}: #{outcome.result}")
  end
end
