# frozen_string_literal: true

module ClientChat
  # Автоответ клиенту, написавшему вне рабочих часов его филиала.
  #
  # Запись в ленте служебная (kind: 'system', без автора): робот не должен
  # попадать ни в метрику времени первого ответа, ни в будущий отчёт по
  # сотрудникам, и не должен снимать диалог с фильтра «Без ответа».
  class AutoReply
    # Клиент, приславший пять сообщений подряд ночью, должен получить один
    # автоответ, а не пять.
    THROTTLE = 6.hours

    DEFAULT_TEXT = 'Здравствуйте! Сейчас мы не работаем и ответим, как только ' \
                   'откроемся. Часы работы: %{hours}.'
    HOURS_PLACEHOLDER = '%{hours}'

    def self.call(conversation)
      new(conversation).call
    end

    def initialize(conversation)
      @conversation = conversation
    end

    def call
      return unless due?

      text = reply_text
      return if text.blank?

      message = @conversation.messages.create!(
        direction: 'out', kind: 'system', body: text, delivery_status: 'pending'
      )
      @conversation.update_columns(auto_reply_sent_at: Time.current, updated_at: Time.current)
      SendClientMessageJob.perform_later(message.id)
      message
    end

    private

    def due?
      return false if WorkingHours.open?(@conversation.department)
      return true if @conversation.auto_reply_sent_at.blank?

      @conversation.auto_reply_sent_at <= THROTTLE.ago
    end

    # Подставляем sub, а не format: текст редактируется в настройках, и
    # случайный процент в нём уронил бы format на ArgumentError.
    def reply_text
      template = Setting.client_chat_after_hours_reply.presence || DEFAULT_TEXT
      hours = WorkingHours.summary(@conversation.department)
      # Шаблон обещает часы, а их нет — лучше промолчать, чем прислать
      # «Часы работы: .»
      return nil if hours.blank? && template.include?(HOURS_PLACEHOLDER)

      template.sub(HOURS_PLACEHOLDER, hours.to_s)
    end
  end
end
