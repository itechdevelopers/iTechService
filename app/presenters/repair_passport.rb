# frozen_string_literal: true

# Read-only агрегатор «Паспорта ремонта» поверх уже существующих данных:
# лога переходов статусов (repair_status_changes) и ремонт-задач (repair_tasks).
# Ничего не пишет в БД. Строит сводку (виды ремонта, мастер, активное время,
# паузы, итог) и хронологический таймлайн для «Хода ремонта».
#
# Мульти-ремонт (гибрид): если передан device_task — виды ремонта и мастер берутся
# из его repair_tasks; временные метрики всё равно общие по ServiceJob, потому что
# лог статусов привязан к работе целиком, а не к отдельной задаче.
class RepairPassport
  # Одно событие таймлайна. kind ∈ :accepted/:started/:paused/:resumed/:completed.
  # duration — длительность СЕГМЕНТА, начинающегося этим событием (сек):
  #   :accepted → сколько устройство лежало до старта, :paused → сколько на паузе,
  #   :started/:resumed → сколько активно работали до следующего события.
  Event = Struct.new(:kind, :at, :user, :reason_name, :duration, keyword_init: true)
  Pause = Struct.new(:reason_name, :seconds, keyword_init: true)

  def initialize(service_job, device_task = nil)
    @service_job = service_job
    @device_task = device_task
  end

  # Достаточно ли данных, чтобы показывать паспорт (лог статусов не пуст).
  def present?
    changes.any?
  end

  # --- Сводка ---

  def repair_kinds
    repair_tasks.map(&:name).compact.uniq
  end

  # Мастер(а): сперва из repair_tasks (repairer назначен на ремонт-строку),
  # иначе — те, кто брал устройство в работу (in_progress-переходы).
  def masters
    from_tasks = repair_tasks.map(&:repairer).compact.uniq
    return from_tasks if from_tasks.any?

    in_progress_users
  end

  def active_seconds
    segments.select { |s| s[:status]&.in_progress? }.sum { |s| s[:seconds] }
  end

  def pauses
    segments
      .select { |s| s[:status]&.paused? }
      .map { |s| Pause.new(reason_name: s[:reason_name], seconds: s[:seconds]) }
  end

  # Паузы, сгруппированные по виду (для сводки: одна строка на причину).
  def pauses_by_reason
    pauses
      .group_by(&:reason_name)
      .map { |name, group| Pause.new(reason_name: name, seconds: group.sum(&:seconds)) }
  end

  def total_pause_seconds
    pauses.sum(&:seconds)
  end

  # Итог в ремонте = активное + паузы (см. формулу заказчика; время ожидания
  # на локации до старта сюда НЕ входит — оно только в «ходе ремонта»).
  def total_seconds
    active_seconds + total_pause_seconds
  end

  # --- Ход ремонта ---

  def timeline
    changes.each_with_index.map do |change, i|
      Event.new(
        kind: event_kind(change),
        at: change.changed_at,
        user: change.user,
        reason_name: change.repair_pause_reason&.name,
        duration: segments[i]&.fetch(:seconds, nil)
      )
    end
  end

  # Итоги для «хода ремонта».
  def totals
    { active_seconds: active_seconds,
      pause_seconds: total_pause_seconds,
      total_seconds: total_seconds }
  end

  private

  def repair_tasks
    (@device_task&.repair_tasks || @service_job.repair_tasks).to_a
  end

  def in_progress_users
    changes.select { |c| c.to_status&.in_progress? }.map(&:user).compact.uniq
  end

  def changes
    @changes ||= @service_job.repair_status_changes
                             .chronological
                             .includes(:to_status, :from_status, :repair_pause_reason, :user)
                             .to_a
  end

  # Момент завершения ремонта для расчёта последнего сегмента.
  # Работа completed → время перехода в completed; иначе (гибрид: эта задача
  # закрыта, но другие ремонты ещё в работе) → done_at этой задачи.
  def finish_at
    last_at = changes.last&.changed_at
    stamp =
      if @service_job.repair_status&.completed?
        changes.reverse.find { |c| c.to_status&.completed? }&.changed_at
      else
        @device_task&.done_at
      end
    stamp && last_at && stamp >= last_at ? stamp : last_at
  end

  # Сегмент = состояние, удерживаемое от одного перехода до следующего (или до
  # finish_at для последнего). Терминальный переход (completed) даёт сегмент 0 сек.
  def segments
    @segments ||= begin
      return [] if changes.empty?

      ends = changes[1..-1].map(&:changed_at) + [finish_at]
      changes.zip(ends).map do |change, end_at|
        end_at = change.changed_at if end_at.nil? || end_at < change.changed_at
        { status: change.to_status,
          reason_name: change.repair_pause_reason&.name,
          seconds: (end_at - change.changed_at).to_i }
      end
    end
  end

  def event_kind(change)
    to = change.to_status
    return :accepted  if to&.waiting?
    return :paused    if to&.paused?
    return :completed if to&.completed?

    if to&.in_progress?
      change.from_status&.paused? ? :resumed : :started
    end
  end
end
