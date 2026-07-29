# frozen_string_literal: true

# Считает время, проведённое заявками в статусе «в процессе ремонта» (in_progress),
# по данным repair_status_changes. Общее ядро для отчётов о работе технарей
# (см. docs/technicians-in-progress-reports-feature.md).
#
# Интервал in_progress = от смены статуса В in_progress до следующей смены статуса
# (любой). Незакрытый интервал (заявка всё ещё в in_progress) закрывается на `now`.
#
# `window` (Range Time..Time) опционален: если задан — интервалы обрезаются по его
# границам (нужно для суточного отчёта-таймлайна). Без него берётся полная
# длительность (нужно для отчёта медианы/среднего по видам работ).
class InProgressDurationService
  Segment = Struct.new(:service_job_id, :started_at, :ended_at, :user_id, keyword_init: true) do
    def seconds
      (ended_at - started_at).to_f
    end
  end

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(service_job_ids:, window: nil, now: Time.current, clip_to_shifts: false)
    @service_job_ids = Array(service_job_ids).uniq
    @window = window
    @now = now
    @clip_to_shifts = clip_to_shifts
  end

  def call
    @segments_by_job = build_segments
    # Обрезка по сменам автора (нормативы + Отчёт 1): ночь/простой вне смены не
    # засчитываются, сегмент без графика за свой день отбрасывается (Вариант A).
    # Отчёт 2 не включает флаг — у него своя суточная обрезка.
    @segments_by_job = regroup(InProgressShiftClipper.call(all_segments)) if @clip_to_shifts
    self
  end

  # Суммарные секунды in_progress по заявке (в пределах window, если задан).
  def seconds_for(service_job_id)
    segments_for(service_job_id).sum(&:seconds)
  end

  def segments_for(service_job_id)
    @segments_by_job.fetch(service_job_id, [])
  end

  def all_segments
    @segments_by_job.values.flatten
  end

  private

  # Список сегментов → { service_job_id => [Segment, ...] }.
  def regroup(segments)
    result = Hash.new { |hash, key| hash[key] = [] }
    segments.each { |segment| result[segment.service_job_id] << segment }
    result
  end

  def in_progress_id
    @in_progress_id ||= RepairStatus.by_code(RepairStatus::IN_PROGRESS).id
  end

  def build_segments
    return {} if @service_job_ids.empty?

    # Завершение берём из device_task.done_at (как Отчёт 1), а не из service_jobs.done_at:
    # на проде обе колонки совпадают, но device_task.done_at — единый источник (Отчёт 1
    # фильтрует по нему), а в dev service_jobs.done_at бывает stale (бэкфилл статусов).
    # Максимум по задачам заявки = момент, когда последняя работа закрыта → дальше
    # in_progress невозможен.
    done_at_by_job = DeviceTask.where(service_job_id: @service_job_ids)
                               .where.not(done_at: nil)
                               .group(:service_job_id)
                               .maximum(:done_at)
    result = Hash.new { |h, k| h[k] = [] }
    changes = RepairStatusChange
              .where(service_job_id: @service_job_ids)
              .order(:service_job_id, :changed_at, :id)
              .to_a

    changes.group_by(&:service_job_id).each do |job_id, job_changes|
      job_changes.each_with_index do |change, index|
        next unless change.to_status_id == in_progress_id

        started = change.changed_at
        succeeding = job_changes[index + 1]
        ended = succeeding ? succeeding.changed_at : @now
        # in_progress не может тянуться дальше завершения работы. Незакрытый интервал
        # (нет смены статуса после in_progress) иначе убегает в `now` и раздувает время
        # у давно завершённых заявок. Обрезаем конец по done_at; если done_at раньше
        # старта (битые/бэкфилл-данные) — интервал вырождается и отсеивается в clip.
        done_at = done_at_by_job[job_id]
        ended = [ended, done_at].min if done_at

        segment = clip(job_id, started, ended, change.user_id)
        result[job_id] << segment if segment
      end
    end
    result
  end

  # Обрезает [started, ended] по границам window. Возвращает Segment либо nil,
  # если пересечения с window нет (или интервал вырожденный).
  def clip(job_id, started, ended, user_id)
    low  = @window ? [started, @window.begin].max : started
    high = @window ? [ended, @window.end].min : ended
    return nil if high <= low

    Segment.new(service_job_id: job_id, started_at: low, ended_at: high, user_id: user_id)
  end
end
