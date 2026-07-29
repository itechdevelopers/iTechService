# frozen_string_literal: true

# Страница «Временные нормативы выполнения работ» (пункт 2 фичи). Раскладка как у
# «Видов ремонта»: слева дерево RepairGroup, справа — таблица нормативов выбранной
# группы (медиана/среднее/образцы по чистым одиночным заявкам). Полная перезагрузка
# при выборе группы (без AJAX). См. docs/repair-time-standards-feature.md.
class RepairTimeStandardsController < ApplicationController
  def index
    authorize :repair_time_standard, :index?
    @repair_groups = RepairGroup.not_archived.roots.order('name asc')

    if params[:group].present?
      @repair_group = RepairGroup.find(params[:group])
      @repair_services = RepairService.not_archived.in_group(@repair_group.id).to_a
      @stats = RepairServiceTimeStandardService.call(repair_service_ids: @repair_services.map(&:id))
    else
      @repair_services = []
      @stats = {}
    end

    respond_to do |format|
      format.html
      format.js
    end
  end

  # Детализация одного вида ремонта: все заявки, где он встречался (эра статусов),
  # с временем `in_progress` рядом. Сортировка по времени убыв. — аномалии наверху.
  # Открывается в новой вкладке кликом по ячейке количества. Одиночные заявки (N=1) —
  # это образцы, по ним время честное; у многозадачных время общее по заявке.
  def show
    authorize :repair_time_standard, :show?
    @repair_service = RepairService.find(params[:id])
    @stat = RepairServiceTimeStandardService.call(repair_service_ids: [@repair_service.id])[@repair_service.id]
    @jobs = detail_rows(@repair_service.id)
  end

  private

  def detail_rows(repair_service_id)
    job_ids = RepairTask
              .joins(device_task: :service_job)
              .where(repair_tasks: { repair_service_id: repair_service_id })
              .where(service_jobs: { excluded_from_reports: false })
              .where.not(device_tasks: { done_at: nil })
              .distinct
              .pluck('device_tasks.service_job_id')

    durations = InProgressDurationService.call(service_job_ids: job_ids)
    works_per_job = DeviceTask.where(service_job_id: job_ids)
                              .joins(:repair_tasks)
                              .group('device_tasks.service_job_id')
                              .count
    jobs_by_id = ServiceJob.where(id: job_ids).index_by(&:id)

    job_ids.filter_map do |jid|
      seconds = durations.seconds_for(jid)
      next if seconds <= 0 # только заявки с отслеженным временем (эра статусов)

      job = jobs_by_id[jid]
      works = works_per_job[jid] || 1
      { id: jid, presentation: job&.presentation, ticket: job&.ticket_number,
        seconds: seconds, works_on_job: works, single: works == 1 }
    end.sort_by { |row| -row[:seconds] }
  end
end
