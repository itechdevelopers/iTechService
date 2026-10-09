# frozen_string_literal: true

# Уведомления GREEN-API от аккаунта MAX, на номер которого пишут клиенты, —
# ещё один транспорт к тем же ClientConversation, с каналом max_phone.
#
# В отличие от ботов здесь нет ни /start, ни ссылок с параметром, ни кнопок:
# клиент просто пишет человеку по номеру. Зато номер отправителя приходит в
# каждом уведомлении, и по нему клиент опознаётся сам.
#
# Аккаунт живой, и ответить с него можно прямо в MAX на телефоне, мимо Айса.
# Такие ответы тоже приходят сюда и попадают в ленту: клиент их получил.
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
  TEXT_TYPES = %w[textMessage extendedTextMessage quotedMessage].freeze
  # Не новые реплики, а действия над уже отправленными. Реакция приходит
  # обычным входящим, и без этого списка лайк клиента на ответ сотрудника
  # снова ставил бы диалог в «Без ответа».
  IGNORED_TYPES = %w[reactionMessage editedMessage deletedMessage].freeze
  # Вложения, которых мы пока не показываем в Айсе. Картинки разбираются
  # отдельно, здесь только то, на что отвечаем отказом.
  UNSUPPORTED = {
    'videoMessage' => 'видео',
    'audioMessage' => 'аудиофайлы',
    'documentMessage' => 'файлы',
    'stickerMessage' => 'стикеры',
    'contactMessage' => 'контакты',
    'locationMessage' => 'геопозицию',
    'pollMessage' => 'опросы'
  }.freeze
  # Незнакомый тип — скорее новый вид вложения, чем пустое событие: лучше
  # показать заглушку, чем потерять реплику, на которую клиент ждёт ответа.
  UNSUPPORTED_FALLBACK = 'вложение'
  # Окончательные отказы, о которых GREEN-API узнаёт уже после того, как
  # принял сообщение. sent/delivered/read ничего не меняют: «отправлено» мы
  # ставим сами, когда GREEN-API принял сообщение к отправке.
  FAILED_STATUSES = {
    'failed' => 'MAX не принял сообщение',
    'noAccount' => 'у получателя нет аккаунта MAX'
  }.freeze

  def update
    return head :unauthorized unless authentic?

    case params[:typeWebhook]
    when 'incomingMessageReceived', 'outgoingMessageReceived'
      handle_message if personal_chat?
    when 'outgoingMessageStatus' then handle_status
    when 'stateInstanceChanged' then log_state
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
    credentials = GreenApi::Channel.fetch(CHANNEL).credentials
    token = credentials.webhook_token
    return false if token.blank?

    presented = request.headers['Authorization'].to_s.sub(/\A(Bearer|Basic)\s+/i, '')
    ActiveSupport::SecurityUtils.variable_size_secure_compare(presented, token) &&
      params.dig(:instanceData, :idInstance).to_s == credentials.instance_id
  end

  # Номер могут добавить в группу — переписка там к диалогам с клиентами не
  # относится. У групп id чата отрицательный.
  def personal_chat?
    chat_id.present? && !chat_id.start_with?('-') &&
      params.dig(:senderData, :chatType).to_s.in?(['', 'user'])
  end

  # Отправлено с телефона канала — то есть ответ клиенту мимо Айса.
  def from_phone?
    params[:typeWebhook] == 'outgoingMessageReceived'
  end

  def handle_message
    data = params[:messageData] || {}
    type = data[:typeMessage].to_s

    if TEXT_TYPES.include?(type)
      text = message_text(data, type)
      record_message(kind: 'text', text: text) if text.present?
    elsif type == 'imageMessage'
      store_photo(data[:fileMessageData] || {})
    elsif type.present? && !IGNORED_TYPES.include?(type)
      store_unsupported(data, UNSUPPORTED.fetch(type, UNSUPPORTED_FALLBACK))
    end
  end

  # Ссылка и ответ с цитатой приходят своими типами, но текст у них лежит в
  # одном и том же поле.
  def message_text(data, type)
    text = type == 'textMessage' ? data.dig(:textMessageData, :textMessage) : data.dig(:extendedTextMessageData, :text)
    text.to_s.strip
  end

  # Фото кладём в ленту сразу, а файл догружаем джобой: скачивание не
  # укладывается во время ответа на уведомление.
  def store_photo(file)
    record = record_message(kind: 'photo', text: file[:caption].to_s.strip)
    return if record.nil?

    AttachClientPhotoJob.perform_later(record.id, file[:downloadUrl].to_s)
  end

  # Вложение, которое мы пока не умеем показывать. Строку в ленту всё равно
  # кладём — иначе сотрудник не узнает, что клиент вообще писал, а клиент
  # будет ждать ответа на сообщение, которого для нас не существовало.
  # Отказ уходит только клиенту: отказывать собственному телефону незачем.
  def store_unsupported(data, label)
    caption = data.dig(:fileMessageData, :caption).to_s.strip
    prefix = from_phone? ? 'отправлено' : 'клиент прислал'
    line = ["[#{prefix}: #{label}]", caption.presence].compact.join(' ')
    return if record_message(kind: 'text', text: line).nil? || from_phone?

    GreenApiReplyJob.perform_later(
      CHANNEL, chat_id, "Мы пока не умеем открывать #{label}. Опишите вопрос текстом или пришлите фото."
    )
  end

  # Побочные эффекты новой записи. Повторная доставка уведомления сюда не
  # доходит: store_message в таком случае возвращает nil. Автоответ — только
  # на реплику клиента: ответ с телефона сам по себе ответ.
  def record_message(kind:, text:)
    record = store_message(kind: kind, body: text.presence)
    return if record.nil?

    ClientChat::AutoReply.call(conversation) unless from_phone?
    record
  end

  # Открытый диалог этого чата либо новый.
  #
  # Клиента по номеру ищем, когда номер стал известен впервые: в новом диалоге
  # или в открытом, который начался с ответа с телефона, — у такого номера ещё
  # не было. Позже не ищем: сотрудник мог перепривязать карточку руками (номер,
  # например, у родственника), и следующее сообщение не должно отменять его
  # решение.
  def conversation
    @conversation ||= begin
      record = ClientConversation.open_for(CHANNEL, chat_id) ||
               ClientConversation.new(channel: CHANNEL, external_chat_id: chat_id)
      phone_was_known = record.contact_phone.present?
      record.assign_attributes(contact_attributes(record.new_record?))
      record.save!
      if !phone_was_known && record.contact_phone.present? && record.client_id.nil?
        record.identify_by_phone(record.contact_phone)
      end
      record
    end
  end

  # У входящего sender* — это клиент; имя перечитываем каждый раз, человек
  # меняет его в профиле когда угодно, а имя из профиля надёжнее имени из
  # записной книжки, которую на этом номере никто не ведёт.
  #
  # У ответа с телефона sender* — наш же аккаунт, о клиенте там только имя
  # чата. Оно годится лишь новому диалогу: в существующем лучше имя, которое
  # клиент сам указал в профиле.
  def contact_attributes(fresh)
    sender = params[:senderData] || {}
    if from_phone?
      return fresh ? { contact_name: sender[:chatName].presence }.compact : {}
    end

    {
      contact_name: sender[:senderName].presence || sender[:senderContactName].presence ||
                    sender[:chatName].presence,
      contact_phone: ClientChat::Phone.normalize(sender[:senderPhoneNumber])
    }.compact
  end

  def chat_id
    params.dig(:senderData, :chatId).to_s
  end

  def store_message(kind:, body:)
    external_id = params[:idMessage].to_s
    return if external_id.blank? || conversation.messages.exists?(external_id: external_id)

    conversation.messages.create!(
      direction: from_phone? ? 'out' : 'in',
      sent_from_phone: from_phone?,
      kind: kind,
      body: body,
      external_id: external_id,
      # Пришедшее уведомлением уже доставлено: входящее — нам, ответ с
      # телефона — клиенту.
      delivery_status: 'sent',
      sent_at: message_time
    )
  rescue ActiveRecord::RecordNotUnique
    # Повтор того же уведомления параллельно с первым: exists? выше его не
    # видит, а уникальный индекс ловит.
    nil
  end

  # Отказ доставки ответа, уже показанного в ленте как отправленный. Сотрудник
  # должен его увидеть, а не ждать реакции на сообщение, которого клиент не
  # получил. Ищем по id, который SendClientMessageJob запомнил при отправке.
  def handle_status
    reason = FAILED_STATUSES[params[:status].to_s]
    return if reason.nil?

    message = ClientMessage.joins(:conversation)
                           .where(client_conversations: { channel: CHANNEL })
                           .find_by(direction: 'out', external_id: params[:idMessage].to_s)
    return if message.nil?

    message.update!(delivery_status: 'failed',
                    delivery_error: [reason, params[:description].presence].compact.join(': '))
    # Открытая карточка подменит строку: «доставлено» сменится на отказ.
    ClientConversationChannel.broadcast_message(message)
  end

  # Аккаунт вышел из authorized — канал молчит, пока его заново не подключат
  # по QR. Лог показывает, с какого момента перестали приходить сообщения.
  def log_state
    state = params[:stateInstance].to_s
    line = "[ClientMaxPhoneWebhook] состояние инстанса: #{state}"
    state == 'authorized' ? Rails.logger.info(line) : Rails.logger.warn(line)
  end

  # Время у GREEN-API в секундах — в отличие от бота MAX, где миллисекунды.
  def message_time
    timestamp = params[:timestamp]
    timestamp.present? ? Time.zone.at(timestamp.to_i) : Time.current
  end
end
