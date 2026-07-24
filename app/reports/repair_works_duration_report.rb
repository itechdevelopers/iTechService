# frozen_string_literal: true

# Отчёт длительности ремонтных работ. За период + подразделение по каждому виду
# работ (repair_service) показывает: количество работ, медианное и среднее время,
# проведённое заявкой в статусе «в процессе ремонта».
#
# Время заявки в in_progress делится поровну между её видами работ: если на заявке
# N услуг и она провела T секунд в ремонте — каждой услуге приписываем T/N.
# Метрика времени берётся за всю жизнь заявки (не обрезается по периоду отчёта);
# период фильтрует лишь то, какие работы попадают в выборку (device_task.done_at).
# См. docs/technicians-in-progress-reports-feature.md.
class RepairWorksDurationReport < BaseReport
  def call
    tasks = RepairTask
            .includes(:repair_service, device_task: :service_job)
            .in_department(department)
            .where(device_tasks: { done_at: period })
            .to_a

    job_ids = tasks.filter_map { |task| task.service_job&.id }.uniq
    durations = InProgressDurationService.call(service_job_ids: job_ids)
    works_per_job = works_count_per_job(job_ids)

    groups = {}
    tasks.each do |task|
      job = task.service_job
      next if job.nil?

      works_on_job = works_per_job[job.id] || 1
      work_seconds = works_on_job.zero? ? 0.0 : durations.seconds_for(job.id) / works_on_job

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

  # Кол-во ремонтных работ (repair_tasks) на каждой заявке — знаменатель для дележа
  # времени поровну.
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
