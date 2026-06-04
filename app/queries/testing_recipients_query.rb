# frozen_string_literal: true

# Кого оповещать о событии тестирования устройства. Общий источник получателей
# для двух каналов:
#   • Telegram (@-теги)  — call (fallback_to_attached: false, поведение по умолчанию)
#   • in-app уведомления — call(fallback_to_attached: true)
#
# Аудитория выводится из направления, в котором «едет» устройство (а не из
# самого события напрямую) — оно определяется (status, failure_action):
#
#   going_to_test? == true:
#     not_started            — отправлено на тест
#     failed + retry         — провалено, уходит на повторный тест
#   → сотрудники ЦЕЛЕВОЙ тест-локации (home-location == target_location).
#
#   going_to_test? == false:
#     passed                 — успешно, вернулось технарям
#     failed + return_to_tech— провалено с возвратом технарям
#   → сотрудники РЕМОНТНЫХ локаций (code LIKE 'repair%') подразделения,
#     к которому относится сам ремонт (service_job.department).
#
# Внутри каждого направления — два среза:
#   working_scope  — кто РАБОТАЕТ СЕЙЧАС по расписанию (точечная адресация);
#   attached_scope — ВСЕ прикреплённые к локации (User.active, без расписания).
#
# fallback_to_attached управляет тем, что вернуть, если по расписанию сейчас
# никого нет:
#   false (Telegram) — отдаём working_scope как есть (может быть пусто → шлём
#                      сообщение без тегов; это решает рендер job'а);
#   true  (in-app)   — если working_scope пуст, отдаём attached_scope (in-app
#                      обязано до кого-то дойти, ника не требует).
#
# Возвращает ActiveRecord::Relation из User.active. Telegram-поведение при
# вызове без аргумента — байт-в-байт прежнее (working_scope).
#
# Паттерн зеркалит GlassStickingRecipientsQuery (пересечение «работают сейчас в
# отделе» × «нужная home-локация»), переиспользует ScheduleEntry.working_now_in.
class TestingRecipientsQuery
  def initialize(session:)
    @session = session
  end

  def call(fallback_to_attached: false)
    scope = primary_scope(fallback_to_attached)
    return User.none if scope.nil?

    scope.order('users.surname ASC, users.name ASC')
  end

  private

  attr_reader :session

  # Выбор среза с учётом fallback: для in-app, если по расписанию пусто —
  # переключаемся на всех прикреплённых к локации.
  def primary_scope(fallback_to_attached)
    working = working_scope
    return working unless fallback_to_attached
    return working if working && working.exists?

    attached_scope
  end

  # Устройство едет (или остаётся) на тест: первая отправка или повторный тест.
  def going_to_test?
    session.not_started? ||
      (session.failed? && session.failure_action == TestingSession::FAILURE_ACTIONS[:retry])
  end

  # --- working: кто работает сейчас по расписанию ---

  def working_scope
    going_to_test? ? testers_working_scope : technicians_working_scope
  end

  # Сотрудники целевой тест-локации, работающие сейчас в её подразделении.
  def testers_working_scope
    location = session.target_location
    return nil if location.nil?

    User.active
        .where(location_id: location.id)
        .where(id: working_now_user_ids(location.department))
  end

  # Сотрудники ремонтных локаций подразделения ремонта, работающие сейчас.
  def technicians_working_scope
    department = session.service_job&.department
    return nil if department.nil?

    User.active
        .where(id: working_now_user_ids(department))
        .joins(:location)
        .where("locations.code LIKE 'repair%'")
  end

  # --- attached: все прикреплённые к локации (fallback для in-app) ---

  def attached_scope
    going_to_test? ? testers_attached_scope : technicians_attached_scope
  end

  # Все активные сотрудники, чья home-локация — целевая тест-локация.
  def testers_attached_scope
    location = session.target_location
    return nil if location.nil?

    User.active.where(location_id: location.id)
  end

  # Все активные сотрудники ремонтных локаций подразделения ремонта.
  def technicians_attached_scope
    department = session.service_job&.department
    return nil if department.nil?

    User.active
        .where(department: department)
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
