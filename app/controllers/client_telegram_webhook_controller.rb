# frozen_string_literal: true

# Публичный бот, через который пишут клиенты. Всё, что сюда приходит, попадает
# в ClientConversation — отвечают сотрудники из Айса, а не из Telegram.
#
# Служебный TelegramWebhookController живёт отдельно и решает другую задачу
# (привязка сотрудников, медиа к работам). Общего кода у них нет намеренно:
# там собеседник обязан быть нашим сотрудником, здесь — наоборот, кто угодно.
#
# Состояние диалога хранится в БД, поэтому use_session! не нужен.
class ClientTelegramWebhookController < Telegram::Bot::UpdatesController
  CHANNEL = 'telegram'
  # Ссылка вида t.me/<bot>?start=dep_vl — своя на каждый филиал. Приходит первым
  # же апдейтом, так что филиал определяется без единого действия клиента.
  DEEP_LINK_PREFIX = 'dep_'
  # Кнопка «Другой город» под приветствием: открывает тот же список филиалов,
  # что и /city.
  CHANGE_BRANCH = 'dep:change'
  GREETING = 'Здравствуйте! Напишите свой вопрос — сотрудник ответит здесь же.'
  # Вложения, которые мы пока не показываем в Айсе. Порядок важен: Telegram
  # кладёт анимацию и видеосообщение рядом с document/video, и разобрать их
  # надо раньше более общих ключей.
  UNSUPPORTED = {
    'voice' => 'голосовые сообщения',
    'video_note' => 'видеосообщения',
    'animation' => 'анимации',
    'video' => 'видео',
    'audio' => 'аудиофайлы',
    'sticker' => 'стикеры',
    'location' => 'геопозицию',
    'document' => 'файлы'
  }.freeze

  def start!(payload = nil, *)
    department = department_from_payload(payload)
    conversation.update!(department: department) if department

    if conversation.department
      respond_with :message, text: "#{GREETING}\n\n#{branch_line}",
                             reply_markup: change_branch_markup
    else
      respond_with :message, text: "#{GREETING}\n\nИз какого вы города?",
                             reply_markup: branch_markup
    end
  end

  # /city — сменить филиал, если определили неверно (клиент уехал в другой
  # город, перешёл по чужой ссылке).
  def city!(*)
    respond_with :message,
                 text: conversation.department ? branch_line : 'Из какого вы города?',
                 reply_markup: branch_markup
  end

  def message(message)
    return store_contact(message) if message['contact'].present?
    return store_photo(message) if message['photo'].present?

    unsupported = UNSUPPORTED.keys.detect { |key| message[key].present? }
    return store_unsupported(message, unsupported) if unsupported

    text = message['text'].to_s.strip
    return if text.blank?

    handle_inbound(message, kind: 'text', body: text)
  end

  def callback_query(data)
    return answer_callback_query(nil) unless data.to_s.start_with?('dep:')

    if data == CHANGE_BRANCH
      answer_callback_query(nil)
      return respond_with(:message, text: 'Из какого вы города?',
                                    reply_markup: branch_markup)
    end

    department = Department.real.find_by(id: data.split(':', 2).last)
    return answer_callback_query('Филиал не найден') if department.nil?

    conversation.update!(department: department)
    answer_callback_query(nil)
    respond_with :message, text: branch_line
  end

  private

  # Открытый диалог этого чата, либо новый. Контактные данные перечитываем на
  # каждом апдейте: в Telegram и имя, и ник меняются в любой момент.
  def conversation
    @conversation ||= begin
      record = ClientConversation.open_for(CHANNEL, chat_id) ||
               ClientConversation.new(channel: CHANNEL, external_chat_id: chat_id)
      record.assign_attributes(contact_attributes)
      record.save!
      record
    end
  end

  def chat_id
    (chat || from)['id'].to_s
  end

  def contact_attributes
    {
      contact_name: [from['first_name'], from['last_name']].reject(&:blank?).join(' ').presence,
      contact_username: from['username'].presence
    }.compact
  end

  def department_from_payload(payload)
    code = payload.to_s.strip
    return nil unless code.start_with?(DEEP_LINK_PREFIX)

    Department.real.find_by(code: code.delete_prefix(DEEP_LINK_PREFIX))
  end

  # Фото кладём в ленту сразу, а файл догружаем джобой: строка нужна здесь и
  # сейчас (иначе повторная доставка апдейта создала бы второе сообщение), а
  # скачивание не укладывается в время ответа вебхука.
  def store_photo(message)
    # Telegram присылает несколько размеров одного фото, последний — крупнейший.
    file_id = message['photo'].last['file_id']
    record = handle_inbound(message, kind: 'photo', body: message['caption'].presence)
    AttachClientPhotoJob.perform_later(record.id, file_id) if record
  end

  # Вложение, которое мы пока не умеем показывать. Строку в ленту всё равно
  # кладём — иначе сотрудник не узнает, что клиент вообще писал, а клиент
  # будет ждать ответа на сообщение, которого для нас не существовало.
  def store_unsupported(message, key)
    label = UNSUPPORTED[key]
    body = ["[клиент прислал: #{label}]", message['caption'].presence].compact.join(' ')
    return if handle_inbound(message, kind: 'text', body: body).nil?

    respond_with :message,
                 text: "Мы пока не умеем открывать #{label}. Опишите вопрос " \
                       'текстом или пришлите фото.'
  end

  # Клиент поделился контактом. Телефон — единственный способ связать диалог с
  # карточкой клиента: Telegram номер сам по себе не отдаёт.
  def store_contact(message)
    phone = PhoneNormalizer.normalize(message['contact']['phone_number'])
    return if phone.blank?

    conversation.update!(contact_phone: phone)
    bind_client(phone)
    return if handle_inbound(message, kind: 'text', body: "[клиент прислал номер: #{phone}]").nil?

    respond_with :message, text: 'Спасибо, номер сохранён.'
  end

  # Опознанный клиент подтягивает и филиал — но только если тот ещё не задан:
  # deep link точнее, он говорит, куда человек обратился сейчас, а не куда
  # приносил устройство в прошлый раз.
  def bind_client(phone)
    client = Client.find_by(full_phone_number: phone)
    return if client.nil?

    attrs = { client: client }
    if conversation.department.nil?
      attrs[:department] = client.service_jobs.order(created_at: :desc).first&.department
    end
    conversation.update!(attrs.compact)
  end

  # Побочные эффекты нового входящего. Повторная доставка апдейта сюда не
  # доходит: store_inbound в таком случае возвращает nil.
  #
  # was_awaiting снимаем ДО создания записи: после неё диалог ждёт ответа в
  # любом случае, и отличить «клиент написал впервые» от «клиент дописывает
  # четвёртое сообщение подряд» было бы уже нечем.
  def handle_inbound(message, kind:, body:)
    was_awaiting = conversation.awaiting_reply?
    record = store_inbound(message, kind: kind, body: body)
    return nil if record.nil?

    ClientChat::AutoReply.call(conversation)
    conversation.notify_new_message(record) unless was_awaiting
    record
  end

  def store_inbound(message, kind:, body:)
    external_id = message['message_id'].to_s
    return if conversation.messages.exists?(external_id: external_id)

    conversation.messages.create!(
      direction: 'in',
      kind: kind,
      body: body,
      external_id: external_id,
      # Входящее доставлено самим фактом прихода апдейта; delivery_status
      # осмыслен только для исходящих.
      delivery_status: 'sent',
      sent_at: Time.zone.at(message['date'])
    )
  rescue ActiveRecord::RecordNotUnique
    # Telegram пере-присылает апдейт, если вебхук не ответил вовремя. Проверка
    # exists? выше ловит это в обычном случае, уникальный индекс — в гонке
    # между двумя воркерами.
    nil
  end

  def branch_line
    "Вы обращаетесь в филиал: #{conversation.department.full_name}."
  end

  def branch_markup
    buttons = Department.real.includes(:city).map do |department|
      [{ text: department.full_name, callback_data: "dep:#{department.id}" }]
    end
    { inline_keyboard: buttons }
  end

  def change_branch_markup
    { inline_keyboard: [[{ text: 'Другой город', callback_data: CHANGE_BRANCH }]] }
  end
end
