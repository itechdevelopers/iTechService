# frozen_string_literal: true

# Закрывает диалоги, в которых сутки не было сообщений, — именно этот момент
# фиксирует длительность диалога.
#
# Раз в час, а не раз в сутки: closed_at тогда отстаёт от реального затухания
# не больше чем на час, иначе каждая длительность была бы систематически
# завышена почти на сутки, и отчёт по времени потерял бы смысл.
#
# Следующее сообщение из того же чата заведёт новый диалог (уникальный индекс
# частичный, только по открытым) — клиент ничего не замечает.
class CloseStaleClientConversationsJob < ApplicationJob
  queue_as :default

  def perform
    closed = 0

    ClientConversation.stale.find_each do |conversation|
      # По одному, а не update_all: закрытие пишет отметку в ленту, и сбой на
      # одном диалоге не должен оставить остальные открытыми.
      conversation.close!
      closed += 1
    rescue StandardError => e
      Rails.logger.error("[CloseStaleClientConversationsJob] диалог #{conversation.id}: " \
                         "#{e.class}: #{e.message}")
    end

    Rails.logger.info("[CloseStaleClientConversationsJob] закрыто диалогов: #{closed}")
  end
end
