# frozen_string_literal: true

# Кого @-тегать в Telegram-уведомлении о событии тестирования устройства.
#
# Аудитория выводится из направления, в котором «едет» устройство (а не из
# самого события напрямую) — оно определяется (status, failure_action):
#
#   going_to_test? == true:
#     not_started            — отправлено на тест
#     failed + retry         — провалено, уходит на повторный тест
#   → тегаем сотрудников ЦЕЛЕВОЙ тест-локации (home-location == target_location),
#     работающих СЕЙЧАС по расписанию в её подразделении.
#
#   going_to_test? == false:
#     passed                 — успешно, вернулось технарям
#     failed + return_to_tech— провалено с возвратом технарям
#   → тегаем сотрудников РЕМОНТНЫХ локаций (code LIKE 'repair%') подразделения,
#     к которому относится сам ремонт (service_job.department), работающих сейчас.
#
# Возвращает ActiveRecord::Relation из User.active (уже отфильтрованных). Ники
# в Telegram (telegram_username) могут отсутствовать — это решает рендер job'а
# (fallback «слать без тегов»), здесь они не фильтруются.
#
# Паттерн зеркалит GlassStickingRecipientsQuery (пересечение «работают сейчас в
# отделе» × «нужная home-локация»), переиспользует ScheduleEntry.working_now_in.
class TestingMentionRecipientsQuery
  def initialize(session:)
    @session = session
  end

  def call
    scope = going_to_test? ? testers_scope : technicians_scope
    return User.none if scope.nil?

    scope.order('users.surname ASC, users.name ASC')
  end

  private

  attr_reader :session

  # Устройство едет (или остаётся) на тест: первая отправка или повторный тест.
  def going_to_test?
    session.not_started? ||
      (session.failed? && session.failure_action == TestingSession::FAILURE_ACTIONS[:retry])
  end

  # Сотрудники целевой тест-локации, работающие сейчас в её подразделении.
  def testers_scope
    location = session.target_location
    return nil if location.nil?

    User.active
        .where(location_id: location.id)
        .where(id: working_now_user_ids(location.department))
  end

  # Сотрудники ремонтных локаций подразделения ремонта, работающие сейчас.
  def technicians_scope
    department = session.service_job&.department
    return nil if department.nil?

    User.active
        .where(id: working_now_user_ids(department))
        .joins(:location)
        .where("locations.code LIKE 'repair%'")
  end

  def working_now_user_ids(department)
    return [] if department.nil?

    ScheduleEntry.working_now_in(department, at: now_in_city(department))
                 .map(&:user_id).uniq
  end

  def now_in_city(department)
    tz = department.city&.time_zone || 'Vladivostok'
    Time.current.in_time_zone(tz)
  end
end
