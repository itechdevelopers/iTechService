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
    text = message['text'].to_s.strip
    # Фото и прочие вложения — отдельный цикл; молча пропускаем, чтобы не
    # записать в ленту пустое сообщение.
    return if text.blank?

    store_inbound(message, text)
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

  def store_inbound(message, text)
    external_id = message['message_id'].to_s
    return if conversation.messages.exists?(external_id: external_id)

    conversation.messages.create!(
      direction: 'in',
      kind: 'text',
      body: text,
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
