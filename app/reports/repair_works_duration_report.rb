# frozen_string_literal: true

# Отчёт длительности ремонтных работ. За период + подразделение по каждому виду
# работ (repair_service) показывает: количество работ, медианное и среднее время,
# проведённое в статусе «в процессе ремонта».
#
# Время считается только по ЧИСТЫМ ОДИНОЧНЫМ заявкам (на заявке ровно один вид
# ремонта, N=1) — только для них «время заявки = время этого вида», без догадок.
# Многозадачные заявки в поштучную статистику не идут (атрибуция времени между
# видами невозможна) — их количество показываем сноской (полноценная вкладка — Цикл 6).
# Время пересекается со сменой автора (clip_to_shifts): ночь/простой вне смены не
# в счёт, заявка вне смены отбрасывается. Период фильтрует выборку по device_task.done_at.
# См. docs/repair-time-standards-feature.md.
class RepairWorksDurationReport < BaseReport
  def call
    tasks = RepairTask
            .includes(:repair_service, device_task: :service_job)
            .in_department(department)
            .where(device_tasks: { done_at: period })
            .to_a

    # Работы, вручную помеченные «Не включать в отчёты», в расчёт не идут — их
    # заявки уходят в сноску внизу (excluded_from_reports, решение 29.07.2026).
    tasks, excluded_tasks = tasks.partition do |task|
      job = task.service_job
      job.nil? || !job.excluded_from_reports?
    end
    result[:excluded_jobs] = excluded_jobs_footnote(excluded_tasks)

    job_ids = tasks.filter_map { |task| task.service_job&.id }.uniq
    # Рабочее время = пересечение in_progress со сменой автора (как в нормативах).
    durations = InProgressDurationService.call(service_job_ids: job_ids, clip_to_shifts: true)
    works_per_job = works_count_per_job(job_ids)

    # Многозадачные заявки — вне поштучной статистики, только счётчик для сноски.
    result[:multi_task_count] = job_ids.count { |jid| (works_per_job[jid] || 1) > 1 }

    groups = {}
    tasks.each do |task|
      job = task.service_job
      next if job.nil?
      next unless works_per_job[job.id] == 1 # только одиночные — время однозначно

      work_seconds = durations.seconds_for(job.id)
      next unless work_seconds.positive? # вне смены / без in_progress-времени → пропуск

      key = task.repair_service_id || "task-#{task.id}"
      group = groups[key] ||= { name: task.name.presence || no_service_label, works: [] }
      group[:works] << {
        seconds: work_seconds,
        service_job_id: job.id,
        service_job_presentation: job.presentation,
        performer: task.performer.try(:short_name)
      }
    end

    result[:data] = groups.values.map { |group| build_row(group) }.sort_by { |row| -row[:count] }
    result
  end

  private

  # Уникальные исключённые заявки → [{ id:, presentation: }] для сноски.
  def excluded_jobs_footnote(excluded_tasks)
    excluded_tasks.filter_map(&:service_job)
                  .uniq(&:id)
                  .map { |job| { id: job.id, presentation: job.presentation } }
                  .sort_by { |job| job[:presentation].to_s }
  end

  def build_row(group)
    durations = group[:works].map { |work| work[:seconds] }
    {
      name: group[:name],
      count: group[:works].size,
      median: median(durations),
      average: durations.sum / durations.size,
      works: group[:works].sort_by { |work| -work[:seconds] }
    }
  end

  # Кол-во ремонтных работ (repair_tasks) на каждой заявке — для отбора одиночных (== 1).
  def works_count_per_job(job_ids)
    DeviceTask.where(service_job_id: job_ids)
              .joins(:repair_tasks)
              .group('device_tasks.service_job_id')
              .count
  end

  def median(values)
    return 0.0 if values.empty?

    sorted = values.sort
    mid = sorted.size / 2
    sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2.0
  end

  def no_service_label
    I18n.t('reports.repair_works_duration.without_service')
  end
end
