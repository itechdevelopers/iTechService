# frozen_string_literal: true

module ClientChat
  # Диалоги одного человека в канале. Человек узнаётся по карточке клиента или
  # по номеру: номер мог прийти в диалог раньше, чем его привязали к карточке,
  # а у бота номера часто нет вовсе — только привязка.
  module PersonChats
    def self.in(channel, client:, phone:)
      scope = ClientConversation.in_channel(channel)
      if client && phone
        scope.where('client_conversations.client_id = ? OR client_conversations.contact_phone = ?', client.id, phone)
      elsif client
        scope.where(client_id: client.id)
      elsif phone
        scope.where(contact_phone: phone)
      else
        scope.none
      end
    end

    # Человек мог писать с двух аккаунтов — берём тот, где он был последним.
    def self.latest(scope)
      scope.order(Arel.sql('client_conversations.last_message_at DESC NULLS LAST'),
                  'client_conversations.created_at DESC').first
    end
  end
end
