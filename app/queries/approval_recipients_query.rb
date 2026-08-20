# frozen_string_literal: true

# Кого @-тегать в группе согласований. Аудитория выводится из направления,
# в котором «едет» запрос:
#
#   pending  — запрос ушёл к медиа   → сотрудники медиа-локации подразделения ремонта;
#   answered — ответ вернулся к технарям → сотрудники ремонтных локаций того же
#              подразделения.
#
# Берём всех, у кого на СЕГОДНЯ стоит рабочая смена, а не только тех, кто на
# смене прямо сейчас: так просил заказчик («отмечает всех технарей, которые по
# расписанию работают в этот день») — ответ по согласованию часто приходит уже
# после конца смены, но адресован именно ей.
#
# fallback_to_attached: для in-app-канала, если на сегодня расписания нет вовсе,
# возвращаем всех прикреплённых к локации — уведомление в АИС обязано до кого-то
# дойти. Для Telegram fallback не нужен: пусто → сообщение уходит без тегов.
#
# Паттерн зеркалит TestingRecipientsQuery, переиспользует ScheduleEntry.working_on.
class ApprovalRecipientsQuery
  def initialize(approval_request:)
    @approval_request = approval_request
  end

  def call(fallback_to_attached: false)
    scope = scheduled_scope
    scope = attached_scope if fallback_to_attached && (scope.nil? || !scope.exists?)
    return User.none if scope.nil?

    scope.order('users.surname ASC, users.name ASC')
  end

  private

  attr_reader :approval_request

  # Направление запроса решает, чья это аудитория: неотвеченный ждёт медиа,
  # отвеченный возвращается технарям.
  def to_media?
    approval_request.pending?
  end

  def scheduled_scope
    scope = attached_scope
    scope&.where(id: working_today_user_ids)
  end

  def attached_scope
    return nil if department.nil?

    base = User.active.where(department: department).joins(:location)
    to_media? ? base.where(locations: { code: 'content' }) : base.where("locations.code LIKE 'repair%'")
  end

  def department
    @department ||= approval_request.service_job&.department
  end

  def working_today_user_ids
    ScheduleEntry.working_on(department, today_in_city).pluck(:user_id).uniq
  end

  # Дату берём в часовом поясе города подразделения: на сервере в UTC «сегодня»
  # наступает раньше, чем во Владивостоке, и смена нашлась бы не та.
  def today_in_city
    tz = department.city&.time_zone || 'Vladivostok'
    Time.current.in_time_zone(tz).to_date
  end
end
