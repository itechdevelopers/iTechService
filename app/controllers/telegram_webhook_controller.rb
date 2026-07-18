# frozen_string_literal: true

# Receives Telegram updates (webhook in production, poller in dev) and binds
# an employee's private chat to their User via the /start linking flow.
#
# Linking strategy (graceful degradation):
#   /start <token>  -> hard match by users.telegram_link_token (deep link)
#   /start          -> fallback match by users.telegram_username (from.username)
#
# Once linked, the employee can attach photos to a service job over chat.
# The entry point is the persistent "📷 Добавить фото" reply button, shown
# after linking and by the /photo command; only linked employees may proceed.
#
# Conversation state (chosen job, "awaiting a ticket number" step) is kept in
# a dedicated file-backed session store — see the session_store config below.
# It is deliberately NOT Rails.cache: dev runs :null_store, which would drop
# session data silently.
class TelegramWebhookController < Telegram::Bot::UpdatesController
  use_session!
  # File store survives restarts and is shared across Puma workers on one
  # host; entries self-expire so abandoned conversations don't pile up.
  self.session_store = [
    :file_store,
    Rails.root.join('tmp', 'telegram_bot_sessions').to_s,
    { expires_in: 1.hour }
  ]

  PHOTO_BUTTON = '📷 Добавить фото'
  MANUAL_ENTRY = 'manual'
  # How many of the employee's recent active jobs to offer as buttons; the
  # rest are reachable via manual ticket-number entry.
  JOB_LIST_LIMIT = 20
  # Keys are PhotoContainer photo columns (<key>_photos); values are labels.
  DIVISIONS = {
    'reception'    => 'Фото при приёмке',
    'in_operation' => 'Фото в процессе ремонта',
    'completed'    => 'Фото готового устройства'
  }.freeze

  def start!(token = nil, *)
    user = find_user(token)

    if user
      user.link_telegram!(from['id'])
      respond_with :message,
                   text: "✅ Готово! Профиль «#{user.short_name}» привязан. " \
                         'Теперь бот сможет присылать вам личные уведомления.',
                   reply_markup: photo_keyboard
    else
      respond_with :message,
                   text: '❌ Не удалось найти ваш профиль. Откройте свой профиль ' \
                         'в системе и нажмите «Подключить Telegram», либо укажите ' \
                         'корректный ник Telegram в профиле.'
    end
  end

  # /photo — (re)shows the entry button for adding photos to a job.
  def photo!(*)
    return respond_not_linked unless current_employee

    respond_with :message,
                 text: 'Нажмите кнопку ниже, чтобы добавить фото к работе.',
                 reply_markup: photo_keyboard
  end

  # Catches plain messages: sent photos, taps on the reply button and, when
  # we are waiting for a manually entered ticket number, that number.
  def message(message)
    return handle_photo(message['photo']) if message['photo'].present?

    text = message['text'].to_s.strip

    if session[:step] == 'awaiting_ticket'
      return current_employee ? handle_ticket_input(text) : respond_not_linked
    end

    return unless text == PHOTO_BUTTON

    current_employee ? render_job_selection : respond_not_linked
  end

  # Handles inline-keyboard taps: picking a job or requesting manual entry.
  def callback_query(data)
    return answer_callback_query('Сначала привяжите профиль') unless current_employee

    if data == MANUAL_ENTRY
      session[:step] = 'awaiting_ticket'
      answer_callback_query(nil)
      respond_with :message, text: 'Введите номер талона:'
    elsif data.start_with?('job:')
      answer_callback_query(nil)
      job = ServiceJob.find_by(id: data.split(':', 2).last)
      job ? store_selected_job(job) : respond_with(:message, text: 'Работа не найдена.')
    elsif data.start_with?('div:')
      answer_callback_query(nil)
      select_division(data.split(':', 2).last)
    else
      answer_callback_query(nil)
    end
  end

  private

  def find_user(token)
    if token.present?
      User.find_by(telegram_link_token: token)
    elsif from && from['username'].present?
      User.active.find_by(telegram_username: from['username'])
    end
  end

  # Resolves the linked employee from the incoming chat. Nil when the chat
  # is not bound to any profile (the verification gate for photo upload).
  def current_employee
    @current_employee ||= User.find_by(telegram_chat_id: from['id'])
  end

  # Inline list of the employee's active (not done, not archived) jobs plus
  # a manual-entry fallback for someone else's job or a mistaken one.
  def render_job_selection
    jobs = current_employee.service_jobs
                           .not_at_done.not_at_archive
                           .order(created_at: :desc)
                           .limit(JOB_LIST_LIMIT)

    buttons = jobs.map { |sj| [{ text: job_button_label(sj), callback_data: "job:#{sj.id}" }] }
    buttons << [{ text: '✏️ Ввести номер вручную', callback_data: MANUAL_ENTRY }]

    text = jobs.any? ? 'Выберите работу:' : 'Активных работ за вами нет. Введите номер талона:'
    respond_with :message, text: text, reply_markup: { inline_keyboard: buttons }
  end

  def handle_ticket_input(text)
    job = ServiceJob.find_by_ticket_number(text)
    if job
      store_selected_job(job)
    else
      # Keep awaiting_ticket so the employee can retry without re-tapping.
      respond_with :message,
                   text: "Работа №#{text} не найдена. Проверьте номер и введите ещё раз:"
    end
  end

  # Shared endpoint for both selection paths: remembers the job, then asks
  # which photo division the upcoming photos belong to.
  def store_selected_job(job)
    session[:job_id] = job.id
    session[:ticket] = job.ticket_number
    session.delete(:step)
    render_division_selection(job)
  end

  def render_division_selection(job)
    buttons = DIVISIONS.map { |key, label| [{ text: label, callback_data: "div:#{key}" }] }
    respond_with :message,
                 text: "Работа №#{job.ticket_number} (#{job.device_short_name}). " \
                       'В какой раздел загрузить фото?',
                 reply_markup: { inline_keyboard: buttons }
  end

  def select_division(division)
    return respond_with(:message, text: 'Неизвестный раздел.') unless DIVISIONS.key?(division)

    job = ServiceJob.find_by(id: session[:job_id])
    unless job
      return respond_with(:message,
                          text: 'Работа не выбрана. Нажмите «📷 Добавить фото» и выберите работу заново.')
    end

    session[:division] = division
    respond_with :message,
                 text: "Раздел «#{DIVISIONS[division]}», работа №#{job.ticket_number}. " \
                       'Пришлите фотографии — можно несколько подряд.'
  end

  # A photo arrived. Requires a job + division already chosen in this session;
  # the actual download + attach runs async (fetching from Telegram and
  # uploading to storage is too slow for the webhook). Division stays in the
  # session so the employee can keep sending photos without re-selecting.
  def handle_photo(photo_sizes)
    return respond_not_linked unless current_employee

    job_id = session[:job_id]
    division = session[:division]
    unless job_id && division
      return respond_with(:message,
                          text: 'Сначала выберите работу и раздел: нажмите «📷 Добавить фото».')
    end

    # Telegram sends several sizes; the last is the highest resolution.
    file_id = photo_sizes.last['file_id']
    TelegramPhotoAttachJob.perform_later(job_id, division, file_id, current_employee.id)

    respond_with :message,
                 text: "📥 Фото принято, добавляю в раздел «#{DIVISIONS[division]}» " \
                       "работы №#{session[:ticket]}."
  end

  def job_button_label(service_job)
    ["№#{service_job.ticket_number}", service_job.device_short_name.presence]
      .compact.join(' ').truncate(60)
  end

  def respond_not_linked
    respond_with :message,
                 text: 'Сначала привяжите профиль: откройте свой профиль в системе ' \
                       'и нажмите «Подключить Telegram».'
  end

  def photo_keyboard
    { keyboard: [[{ text: PHOTO_BUTTON }]], resize_keyboard: true }
  end
end
