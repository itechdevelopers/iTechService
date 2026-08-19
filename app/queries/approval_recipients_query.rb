# frozen_string_literal: true

# Кого @-тегать в группе согласований. Аудитория выводится из направления,
# в котором «едет» запрос:
#
#   pending  — запрос ушёл к медиа   → сотрудники медиа-локации подразделения ремонта;
#   answered — ответ вернулся к технарям → сотрудники ремонтных локаций того же
#              подразделения.
#
# Берём только тех, кто работает сейчас по расписанию: тегать смену, которая
# закончилась вчера, бессмысленно. Если сейчас никого нет — вернём пусто, и job
# отправит сообщение без префикса тегов (доставка важнее адресности).
#
# Паттерн зеркалит TestingRecipientsQuery, переиспользует ScheduleEntry.working_now_in.
class ApprovalRecipientsQuery
  def initialize(approval_request:)
    @approval_request = approval_request
  end

  def call
    scope = approval_request.pending? ? media_scope : technicians_scope
    return User.none if scope.nil?

    scope.order('users.surname ASC, users.name ASC')
  end

  private

  attr_reader :approval_request

  def media_scope
    return nil if department.nil?

    User.active
        .where(department: department)
        .where(id: working_now_user_ids)
        .joins(:location)
        .where(locations: { code: 'content' })
  end

  def technicians_scope
    return nil if department.nil?

    User.active
        .where(department: department)
        .where(id: working_now_user_ids)
        .joins(:location)
        .where("locations.code LIKE 'repair%'")
  end

  def department
    @department ||= approval_request.service_job&.department
  end

  def working_now_user_ids
    ScheduleEntry.working_now_in(department, at: now_in_city).map(&:user_id).uniq
  end

  def now_in_city
    tz = department.city&.time_zone || 'Vladivostok'
    Time.current.in_time_zone(tz)
  end
end
