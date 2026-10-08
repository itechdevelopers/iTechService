# frozen_string_literal: true

module ClientChat
  # Прошлая переписка в том же чате — для ленты карточки диалога.
  #
  # Диалог остаётся единицей работы: метрики, ответственный, закрытие — всё
  # своё. А показывается переписка чата целиком, потому что для сотрудника это
  # один разговор с человеком, просто с перерывами.
  #
  # «Тот же чат» — та же пара канал + id чата, а не тот же клиент: ответ из
  # карточки уходит только в этот чат, и чужие чаты клиента в ленте
  # выглядели бы так, будто туда тоже можно ответить.
  class History
    # Сколько прошлых диалогов показывать сразу; более ранние — по кнопке.
    LIMIT = 5

    attr_reader :conversations, :hidden_count, :newer

    def initialize(conversation, all: false)
      chat = ClientConversation.where(channel: conversation.channel,
                                      external_chat_id: conversation.external_chat_id)
      # /start без единого сообщения тоже заводит диалог, и через сутки тишины
      # он закрывается. В истории от него осталась бы одна строка «закрыт».
      talked = chat.where(id: ClientMessage.where.not(kind: 'system').select(:client_conversation_id))

      earlier = talked.where('client_conversations.id < ?', conversation.id)
      shown = all ? earlier.order(:id) : earlier.order(id: :desc).limit(LIMIT)
      @conversations = shown.includes(:assigned_user).to_a.sort_by(&:id)
      @hidden_count = all ? 0 : [earlier.count - @conversations.size, 0].max

      # Карточку закрытого диалога открывают из списка закрытых или из карточки
      # клиента — оттуда должен быть виден путь к продолжению разговора.
      later = chat.where('client_conversations.id > ?', conversation.id)
      @newer = [later.merge(talked).order(:id).first, later.opened.order(:id).first].compact.min_by(&:id)

      @messages = ClientMessage.where(client_conversation_id: @conversations.map(&:id))
                               .chronological.includes(:user).group_by(&:client_conversation_id)
    end

    def any?
      @conversations.any?
    end

    def messages_of(conversation)
      @messages.fetch(conversation.id, [])
    end
  end
end
