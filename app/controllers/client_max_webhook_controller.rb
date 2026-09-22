# frozen_string_literal: true

# Публичный бот MAX, через который пишут клиенты, — второй транспорт к тем же
# ClientConversation, что и телеграмный. Разница в устройстве: там апдейты
# разбирает гем, здесь приходит обычный JSON, и разбирать его нам самим.
#
# Обработчик не ходит в сеть: MAX закрывает соединение, если вебхук молчит
# дольше двух секунд, и присылает апдейт заново. Поэтому всё исходящее —
# джобой, а сюда попадает только запись в базу.
class ClientMaxWebhookController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  skip_after_action :verify_authorized

  CHANNEL = 'max'
  # Ссылка вида <бот>?start=dep_vl — своя на каждый филиал, как в Telegram.
  # Payload приезжает в bot_started, так что город известен до первого слова.
  DEEP_LINK_PREFIX = 'dep_'
  GREETING = 'Здравствуйте! Напишите свой вопрос — сотрудник ответит здесь же.'
  # Кнопка под приветствием: открывает тот же список, что и команда /city.
  CHANGE_CITY = 'dep:change'
  CITY_COMMAND = '/city'
  # Вложения, которые мы пока не показываем в Айсе. Картинки разбираются
  # отдельно, здесь только то, на что отвечаем отказом.
  UNSUPPORTED = {
    'video' => 'видео',
    'audio' => 'аудиофайлы',
    'file' => 'файлы',
    'sticker' => 'стикеры',
    'contact' => 'контакты',
    'location' => 'геопозицию',
    'share' => 'ссылки-карточки'
  }.freeze
  UNSUPPORTED_FALLBACK = 'вложение'

  def update
    return head :unauthorized unless authentic?

    case params[:update_type]
    when 'bot_started' then handle_bot_started
    when 'message_created' then handle_message_created
    when 'message_callback' then handle_message_callback
    when 'bot_stopped' then handle_bot_stopped
    end

    head :ok
  end

  private

  # Секрет придумываем мы сами при подписке, MAX возвращает его в заголовке.
  # Другой аутентификации у эндпоинта нет, поэтому незаданный секрет — это
  # отказ, а не «пропускаем всех».
  def authentic?
    secret = ENV['CLIENT_MAX_WEBHOOK_SECRET'].to_s
    return false if secret.blank?

    ActiveSupport::SecurityUtils.variable_size_secure_compare(
      request.headers['X-Max-Bot-Api-Secret'].to_s, secret
    )
  end

  def handle_bot_started
    city = city_from_payload(params[:payload])
    conversation.update!(city: city) if city

    if conversation.city
      reply("#{GREETING}\n\n#{city_line}", change_city_buttons)
    else
      reply("#{GREETING}\n\nИз какого вы города?", city_buttons)
    end
  end

  def handle_message_callback
    callback = params[:callback] || {}
    callback_id = callback[:callback_id].to_s

    case callback[:payload].to_s
    when CHANGE_CITY
      answer_callback(callback_id)
      reply('Из какого вы города?', city_buttons)
    when /\Acity:(\d+)\z/
      select_city(callback_id, City.find_by(id: Regexp.last_match(1)))
    else
      answer_callback(callback_id)
    end
  end

  def select_city(callback_id, city)
    return answer_callback(callback_id, 'Город не найден') if city.nil?

    conversation.update!(city: city)
    answer_callback(callback_id)
    reply(city_line, change_city_buttons)
  end

  def handle_message_created
    body = params.dig(:message, :body) || {}
    text = body[:text].to_s.strip
    # Команда бота приезжает обычным текстом. В ленту её не кладём: сотруднику
    # она ничего не говорит, а клиент ждёт не ответа, а список городов.
    return ask_city if text == CITY_COMMAND

    attachments = Array(body[:attachments])
    image = attachments.find { |attachment| attachment[:type].to_s == 'image' }
    return store_photo(body, text, image) if image

    label = attachments.map { |attachment| UNSUPPORTED[attachment[:type].to_s] }.compact.first
    label ||= UNSUPPORTED_FALLBACK if attachments.any?
    return store_unsupported(body, text, label) if label

    handle_inbound(body, kind: 'text', text: text.presence)
  end

  # Клиент остановил бота: наши ответы ему больше не доходят. Сотрудник должен
  # узнать это из ленты, а не из тишины в ответ на отправленное сообщение.
  # Диалог на такое событие не заводим — писать всё равно некому.
  def handle_bot_stopped
    ClientConversation.open_for(CHANNEL, chat_id)
                      &.add_system_message('Клиент остановил бота — ответы ему больше не доставляются')
  end

  # Фото кладём в ленту сразу, а файл догружаем джобой: скачивание не
  # укладывается во время ответа вебхука.
  def store_photo(body, caption, image)
    record = handle_inbound(body, kind: 'photo', text: caption.presence)
    return if record.nil?

    AttachClientPhotoJob.perform_later(record.id, image.dig(:payload, :url).to_s)
  end

  # Вложение, которое мы пока не умеем показывать. Строку в ленту всё равно
  # кладём — иначе сотрудник не узнает, что клиент вообще писал, а клиент
  # будет ждать ответа на сообщение, которого для нас не существовало.
  def store_unsupported(body, caption, label)
    line = ["[клиент прислал: #{label}]", caption.presence].compact.join(' ')
    return if handle_inbound(body, kind: 'text', text: line).nil?

    reply("Мы пока не умеем открывать #{label}. Опишите вопрос текстом или пришлите фото.")
  end

  # Побочные эффекты нового входящего. Повторная доставка апдейта сюда не
  # доходит: store_inbound в таком случае возвращает nil.
  def handle_inbound(body, kind:, text:)
    return if text.blank? && kind != 'photo'

    record = store_inbound(external_id: body[:mid].to_s, kind: kind, body: text,
                           at: params.dig(:message, :timestamp))
    return if record.nil?

    ClientChat::AutoReply.call(conversation)
    record
  end

  # Открытый диалог этого чата, либо новый. Контактные данные перечитываем на
  # каждом апдейте: имя и ник у человека меняются в любой момент.
  def conversation
    @conversation ||= begin
      record = ClientConversation.open_for(CHANNEL, chat_id) ||
               ClientConversation.new(channel: CHANNEL, external_chat_id: chat_id)
      record.assign_attributes(contact_attributes)
      record.save!
      record
    end
  end

  def ask_city
    reply(conversation.city ? city_line : 'Из какого вы города?', city_buttons)
  end

  def reply(text, buttons = nil)
    MaxBotReplyJob.perform_later(chat_id, text, buttons)
  end

  def answer_callback(callback_id, notification = nil)
    MaxCallbackAnswerJob.perform_later(callback_id, notification)
  end

  def city_line
    "Ваш город: #{conversation.city.name}."
  end

  # Клиенту показываем только города: филиал внутри города он всё равно не
  # выбирает осознанно, а список из семи строк читался тяжело.
  def city_buttons
    City.with_real_departments.map do |city|
      mark = ClientChat::CityMark.for(city)
      [{ type: 'callback', text: "#{mark} #{city.name} #{mark}", payload: "city:#{city.id}" }]
    end
  end

  def change_city_buttons
    [[{ type: 'callback', text: 'Другой город', payload: CHANGE_CITY }]]
  end

  # В bot_started идентификатор чата лежит в корне, в message_created — у
  # получателя сообщения.
  def chat_id
    (params[:chat_id] || params.dig(:message, :recipient, :chat_id)).to_s
  end

  # У message_callback в message.sender лежит бот — кнопки отправляли мы, —
  # а человек сидит в callback.user. Поэтому callback разбираем раньше
  # сообщения, иначе контакт диалога затёрся бы именем бота.
  def sender
    params[:user] || params.dig(:callback, :user) || params.dig(:message, :sender) || {}
  end

  def contact_attributes
    {
      contact_name: [sender[:first_name], sender[:last_name]].reject(&:blank?).join(' ').presence,
      contact_username: sender[:username].presence
    }.compact
  end

  # Ссылка остаётся адресной по филиалу — её печатают на конкретной точке, —
  # но в диалог кладём его город: филиал нам больше ни для чего не нужен.
  def city_from_payload(payload)
    code = payload.to_s.strip
    return nil unless code.start_with?(DEEP_LINK_PREFIX)

    Department.real.find_by(code: code.delete_prefix(DEEP_LINK_PREFIX))&.city
  end

  def store_inbound(external_id:, kind:, body:, at:)
    return if external_id.blank? || conversation.messages.exists?(external_id: external_id)

    conversation.messages.create!(
      direction: 'in',
      kind: kind,
      body: body,
      external_id: external_id,
      # Входящее доставлено самим фактом прихода апдейта; delivery_status
      # осмыслен только для исходящих.
      delivery_status: 'sent',
      sent_at: message_time(at)
    )
  rescue ActiveRecord::RecordNotUnique
    # MAX пере-присылает апдейт, если вебхук не ответил вовремя. Проверка
    # exists? выше ловит это в обычном случае, уникальный индекс — в гонке
    # между двумя воркерами.
    nil
  end

  # Время в апдейтах — миллисекунды, а не секунды: Time.zone.at без деления
  # уводит сообщение на пятьдесят тысяч лет вперёд.
  def message_time(timestamp)
    return Time.current if timestamp.blank?

    Time.zone.at(timestamp.to_i / 1000)
  end
end
