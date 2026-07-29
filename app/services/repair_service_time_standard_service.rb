# frozen_string_literal: true

# Вычисляемые временные нормативы видов ремонта (пункт 2 фичи).
# По набору repair_service_id считает медиану/среднее времени `in_progress` и два
# счётчика. См. docs/repair-time-standards-feature.md.
#
# Граница данных: время `in_progress` существует только с момента запуска статусов
# (repair_status_changes). Поэтому вся популяция ограничена заявками с отслеженным
# in_progress-временем (`InProgressDurationService#seconds_for > 0`) — до статусов
# ремонтов «не видно».
#
# Определения (решения 1–2, согласовано 29.07.2026):
# - `sample` (для median/average/sample_count) — repair_task, где ОДНОВРЕМЕННО:
#   заявка одиночная (ровно одна repair_task, N=1); не исключена; `done_at` есть
#   (интервал закрыт); in_progress-время > 0. Только для N=1 «время заявки = время
#   вида ремонта» без дележа.
# - `total_count` — все repair_task этого вида (одиночные + многозадачные) на
#   завершённых, не исключённых заявках с отслеженным in_progress-временем.
#
# Возвращает Hash: repair_service_id => Stat(median, average, sample_count, total_count).
# Виды без измеренных данных в результате отсутствуют (caller подставляет «нет данных»).
class RepairServiceTimeStandardService
  Stat = Struct.new(:median, :average, :sample_count, :total_count, keyword_init: true)

  def self.call(**kwargs)
    new(**kwargs).call
  end

  # repair_service_ids: nil → по всем видам ремонта; иначе — по указанным (напр. группе).
  def initialize(repair_service_ids: nil)
    @repair_service_ids = repair_service_ids && Array(repair_service_ids).uniq
  end

  def call
    rows = base_rows
    return {} if rows.empty?

    job_ids = rows.map(&:last).uniq
    # clip_to_shifts: время пересекается со сменой автора; образец без графика за свой
    # день отбрасывается (Вариант A). См. docs/repair-time-standards-feature.md.
    durations = InProgressDurationService.call(service_job_ids: job_ids, clip_to_shifts: true)

    # Только заявки с реально отслеженным in_progress-временем (эра статусов).
    measured = rows.select { |(_sid, jid)| durations.seconds_for(jid).positive? }
    return {} if measured.empty?

    works_per_job = works_count_per_job(measured.map(&:last).uniq)

    accumulate(measured, durations, works_per_job)
  end

  private

  # [[repair_service_id, service_job_id], ...] по завершённым, не исключённым работам
  # с указанным видом ремонта. Фильтр single-task делается позже (нужен полный счётчик
  # repair_tasks на заявке, а не только по видам из выборки).
  def base_rows
    scope = RepairTask
            .joins(device_task: :service_job)
            .where(service_jobs: { excluded_from_reports: false })
            .where.not(device_tasks: { done_at: nil })
            .where.not(repair_tasks: { repair_service_id: nil })
    scope = scope.where(repair_tasks: { repair_service_id: @repair_service_ids }) if @repair_service_ids
    scope.pluck('repair_tasks.repair_service_id', 'device_tasks.service_job_id')
  end

  # service_job_id => число repair_tasks на всей заявке (across device_tasks). Знаменатель
  # для определения одиночности (== 1). Считаем ВСЕ виды, а не только из выборки.
  def works_count_per_job(job_ids)
    DeviceTask.where(service_job_id: job_ids)
              .joins(:repair_tasks)
              .group('device_tasks.service_job_id')
              .count
  end

  def accumulate(measured, durations, works_per_job)
    acc = Hash.new { |hash, key| hash[key] = { times: [], total: 0 } }
    measured.each do |(service_id, job_id)|
      bucket = acc[service_id]
      bucket[:total] += 1
      # Одиночная заявка (N=1) → её полное in_progress-время = время этого вида ремонта.
      bucket[:times] << durations.seconds_for(job_id) if works_per_job[job_id] == 1
    end

    acc.transform_values do |bucket|
      times = bucket[:times]
      Stat.new(
        median: times.empty? ? nil : median(times),
        average: times.empty? ? nil : times.sum / times.size,
        sample_count: times.size,
        total_count: bucket[:total]
      )
    end
  end

  def median(values)
    sorted = values.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end
end
