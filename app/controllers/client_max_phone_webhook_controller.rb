# frozen_string_literal: true

# Уведомления GREEN-API от аккаунта MAX, на номер которого пишут клиенты, —
# ещё один транспорт к тем же ClientConversation, с каналом max_phone.
#
# В отличие от ботов здесь нет ни /start, ни ссылок с параметром, ни кнопок:
# клиент просто пишет человеку по номеру. Зато номер отправителя приходит в
# каждом уведомлении, и по нему клиент опознаётся сам.
#
# Обработчик не ходит в сеть, всё исходящее — джобами. Недоставленное
# уведомление GREEN-API повторяет раз в минуту в течение суток, поэтому
# отвечаем 200 на всё, что разобрали или сознательно пропустили, а от
# повторов защищает дедуп по idMessage.
class ClientMaxPhoneWebhookController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_after_action :verify_authorized

  CHANNEL = 'max_phone'

  def update
    return head :unauthorized unless authentic?

    case params[:typeWebhook]
    when 'incomingMessageReceived' then handle_incoming if personal_chat?
    end

    head :ok
  end

  private

  # Токен придумываем мы и прописываем в настройки инстанса, GREEN-API
  # возвращает его в Authorization — со схемой Bearer или Basic, смотря как
  # его задали. Номер инстанса сверяем вдобавок: уведомления чужого инстанса
  # (того же WhatsApp для рассылок), направленные сюда по ошибке, не должны
  # превращаться в диалоги.
  def authentic?
    token = MaxPhoneApi.webhook_token
    return false if token.blank?

    presented = request.headers['Authorization'].to_s.sub(/\A(Bearer|Basic)\s+/i, '')
    ActiveSupport::SecurityUtils.variable_size_secure_compare(presented, token) &&
      params.dig(:instanceData, :idInstance).to_s == MaxPhoneApi.instance_id
  end

  # Номер могут добавить в группу — переписка там к диалогам с клиентами не
  # относится. У групп id чата отрицательный.
  def personal_chat?
    chat_id.present? && !chat_id.start_with?('-') &&
      params.dig(:senderData, :chatType).to_s.in?(['', 'user'])
  end

  def handle_incoming
    text = incoming_text
    return if text.blank?

    handle_inbound(kind: 'text', text: text)
  end

  # Ссылка и ответ с цитатой приходят своими типами, но текст у них лежит в
  # одном и том же поле.
  def incoming_text
    data = params[:messageData] || {}
    text =
      case data[:typeMessage].to_s
      when 'textMessage' then data.dig(:textMessageData, :textMessage)
      when 'extendedTextMessage', 'quotedMessage' then data.dig(:extendedTextMessageData, :text)
      end
    text.to_s.strip
  end

  # Побочные эффекты нового входящего. Повторная доставка уведомления сюда не
  # доходит: store_inbound в таком случае возвращает nil.
  def handle_inbound(kind:, text:)
    record = store_inbound(kind: kind, body: text.presence)
    return if record.nil?

    ClientChat::AutoReply.call(conversation)
    record
  end

  # Открытый диалог этого чата либо новый. Имя перечитываем на каждом
  # уведомлении: человек меняет его в профиле когда угодно.
  #
  # Клиента по номеру ищем только у нового диалога. В открытом сотрудник мог
  # уже перепривязать карточку руками (номер, например, у родственника), и
  # каждое следующее сообщение не должно отменять его решение.
  def conversation
    @conversation ||= begin
      record = ClientConversation.open_for(CHANNEL, chat_id) ||
               ClientConversation.new(channel: CHANNEL, external_chat_id: chat_id)
      fresh = record.new_record?
      record.assign_attributes(contact_attributes)
      record.save!
      record.identify_by_phone(record.contact_phone) if fresh
      record
    end
  end

  # Имя из профиля надёжнее имени из записной книжки аккаунта: книжку на этом
  # номере никто не ведёт.
  def contact_attributes
    sender = params[:senderData] || {}
    {
      contact_name: sender[:senderName].presence || sender[:senderContactName].presence ||
                    sender[:chatName].presence,
      contact_phone: PhoneNormalizer.normalize(sender[:senderPhoneNumber]).presence
    }.compact
  end

  def chat_id
    params.dig(:senderData, :chatId).to_s
  end

  def store_inbound(kind:, body:)
    external_id = params[:idMessage].to_s
    return if external_id.blank? || conversation.messages.exists?(external_id: external_id)

    conversation.messages.create!(
      direction: 'in',
      kind: kind,
      body: body,
      external_id: external_id,
      # Входящее доставлено самим фактом уведомления; delivery_status
      # осмыслен только для исходящих.
      delivery_status: 'sent',
      sent_at: message_time
    )
  rescue ActiveRecord::RecordNotUnique
    # Повтор того же уведомления параллельно с первым: exists? выше его не
    # видит, а уникальный индекс ловит.
    nil
  end

  # Время у GREEN-API в секундах — в отличие от бота MAX, где миллисекунды.
  def message_time
    timestamp = params[:timestamp]
    timestamp.present? ? Time.zone.at(timestamp.to_i) : Time.current
  end
end
