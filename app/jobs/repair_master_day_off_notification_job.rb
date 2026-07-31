# frozen_string_literal: true

# Утреннее напоминание: устройство осталось «В процессе ремонта», а мастер,
# взявший его в работу, сегодня не работает по расписанию.
#
# Запускается cron'ом в 11:00 по Владивостоку (config/schedule.yml), когда смена
# ремонта уже идёт. Для каждой работы в статусе in_progress, стоящей на локации
# «Ремонт», берёт мастера (последний переход в in_progress — current_in_progress_user)
# и проверяет его расписание на сегодня. Если у мастера нет ни одной рабочей записи
# на сегодня (выходной / отпуск / больничный / нет записи), а сам он состоит в
# расписании, — шлём уведомление всем, кто прямо сейчас на смене на локации «Ремонт»
# того же подразделения (ScheduleEntry.working_now_in + фильтр по users.location_id).
#
# Каналы: in-app Notification (колокольчик) + личный Telegram тем, у кого привязан.
# Идемпотентность — как в KanbanCardDeadlineReminderJob: повторный запуск в тот же
# день не задублирует уведомление той же паре (получатель, работа).
#
# Замечание по timezone: даты расписания date-only и привязаны к городу; job берёт
# Date.current в дефолтной зоне приложения (Владивосток) — корректно для основного
# города, для мультигорода возможен сдвиг на границе суток.
class RepairMasterDayOffNotificationJob < ApplicationJob
  queue_as :default

  KIND = 'repair_master_day_off'

  def perform
    in_progress = RepairStatus.by_code(RepairStatus::IN_PROGRESS)
    return unless in_progress

    ServiceJob.where(repair_status_id: in_progress.id).includes(:location).find_each do |job|
      next unless job.location&.is_repair?

      master = job.current_in_progress_user
      next unless master && master_off_today?(master)

      recipients = repair_crew_on_shift_now(job, master)
      next if recipients.empty?

      message = build_message(job, master)
      recipients.each do |user|
        created = create_notification(user, job, message)
        notify_telegram(user, job, message) if created && user.telegram_linked?
      end
    end
  end

  private

  # Мастер «не работает сегодня» = состоит в расписании (иначе судить не о чем),
  # но на сегодня у него нет ни одной записи с рабочей занятостью.
  def master_off_today?(master)
    return false unless ScheduleGroupMembership.exists?(user_id: master.id, active: true)

    !ScheduleEntry
      .where(user_id: master.id, date: Date.current)
      .joins(:occupation_type)
      .where(occupation_types: { counts_as_working: true })
      .exists?
  end

  # Все, кто прямо сейчас на смене в подразделении работы И закреплён за локацией
  # «Ремонт» этого подразделения (users.location_id). Мастера исключаем на всякий
  # случай — он и так не должен попасть (у него выходной).
  def repair_crew_on_shift_now(job, master)
    department = job.location.department
    return [] unless department

    repair_location_ids = Location.repair.in_department(department).pluck(:id)
    return [] if repair_location_ids.empty?

    repair_user_ids = User.active.where(location_id: repair_location_ids).pluck(:id).to_set

    ScheduleEntry.working_now_in(department)
                 .map(&:user)
                 .select { |u| repair_user_ids.include?(u.id) }
                 .reject { |u| u.id == master.id }
                 .uniq
  end

  def build_message(job, master)
    "Мастер #{master.short_name} сегодня не работает, а ремонт по талону " \
      "№#{job.ticket_number} остался в статусе «В процессе ремонта». " \
      'Возьмите работу или смените статус.'
  end

  # Возвращает true, если уведомление создано; false — если уже уведомляли сегодня.
  def create_notification(user, job, message)
    return false if already_notified_today?(user, job)

    notification = Notification.create!(
      user: user,
      message: message,
      url: Rails.application.routes.url_helpers.service_job_path(job),
      referenceable: job,
      kind: KIND
    )
    UserNotificationChannel.broadcast_to(notification.user, notification)
    true
  end

  # Тот же текст, что и in-app, плюс встроенная HTML-ссылка на работу.
  # Экранируем message: SendTelegramMessage шлёт с parse_mode HTML.
  def notify_telegram(user, job, message)
    url  = Rails.application.routes.url_helpers.service_job_url(job)
    text = "#{CGI.escapeHTML(message)}\n\n<a href=\"#{url}\">Открыть ремонт</a>"
    SendTelegramMessage.call(chat_id: user.telegram_chat_id, text: text)
  end

  # Идемпотентность: повторный запуск cron в тот же день не создаёт дубль по той же
  # паре (получатель, работа). Фильтруем по kind, чтобы не пересечься с другими
  # уведомлениями по этой же работе (например, маячками repair_attention).
  def already_notified_today?(user, job)
    Notification
      .where(user: user, referenceable: job, kind: KIND)
      .where('created_at >= ?', Time.current.beginning_of_day)
      .exists?
  end
end
