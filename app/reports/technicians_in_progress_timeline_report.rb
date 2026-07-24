# frozen_string_literal: true

# Отчёт «Отслеживание статуса "В процессе ремонта" технических специалистов».
# За ОДИН день по подразделению(ям): для каждого технаря — горизонтальная шкала
# времени в статусе in_progress, поделённая между работами (заявками), в сравнении
# с плановыми часами смены. Плюс «бережность» — заработанные деньги (маржа работ =
# розница − себестоимость запчастей).
#
# Развилки (согласовано, см. docs/technicians-in-progress-reports-feature.md):
# - Ширина полосы = плановые часы смены (ScheduleEntry); незаполненный хвост = время
#   «не в ремонте». Если графика нет — база полосы = само in_progress-время.
# - Строки = все технари из графика за день + те, у кого было in_progress-время.
# - Деньги: маржу работ заявки, завершённых в этот день, получает технарь с
#   наибольшим in_progress-временем по этой заявке (одна заявка → один получатель,
#   без задвоения между технарями).
class TechniciansInProgressTimelineReport < BaseReport
  def only_day?
    true
  end

  def call
    # Окно — суточный `period` из BaseReport (в OS-зоне, как во всех отчётах). Свой
    # `day.beginning_of_day` (в Time.zone) давал бы окно в другой временной зоне, чем
    # то, что использует остальная отчётная система, и работы у границы суток выпадали.
    day = start_date.to_time(:local).to_date
    window = period

    planned_hours, scheduled_users = scheduled_technicians(day)

    job_ids = candidate_job_ids(window)
    durations = InProgressDurationService.call(service_job_ids: job_ids, window: window)
    seconds_by_user_job = aggregate_seconds(durations.all_segments)

    involved_job_ids = seconds_by_user_job.values.flat_map(&:keys).uniq
    job_ticket = ServiceJob.where(id: involved_job_ids).pluck(:id, :ticket_number).to_h
    job_margin = job_margins(involved_job_ids, window)
    job_earner = dominant_earner(seconds_by_user_job)

    user_ids = (planned_hours.keys + seconds_by_user_job.keys).uniq
    users = scheduled_users.merge(load_users(user_ids - scheduled_users.keys))

    result[:day] = day
    result[:rows] = user_ids.map do |uid|
      build_row(uid, users[uid], planned_hours[uid] || 0.0,
                seconds_by_user_job[uid] || {}, job_ticket, job_margin, job_earner)
    end.sort_by { |row| row[:name].to_s }
    result
  end

  private

  def build_row(uid, user, planned_hours, job_seconds, job_ticket, job_margin, job_earner)
    segments = job_seconds.map do |jid, secs|
      money = job_earner[jid] == uid ? (job_margin[jid] || 0.0) : 0.0
      { job_id: jid, ticket: job_ticket[jid], seconds: secs, money: money }
    end.sort_by { |seg| -seg[:seconds] }

    in_progress_seconds = segments.sum { |seg| seg[:seconds] }
    planned_seconds = planned_hours * 3600
    {
      user: user,
      name: user.try(:short_name),
      planned_hours: planned_hours,
      in_progress_seconds: in_progress_seconds,
      bar_base_seconds: planned_seconds.positive? ? planned_seconds : in_progress_seconds,
      scheduled: planned_hours.positive?,
      money: segments.sum { |seg| seg[:money] },
      segments: segments
    }
  end

  # Рабочие смены за день → user_id => суммарные плановые часы, и user_id => User.
  def scheduled_technicians(day)
    scope = ScheduleEntry.where(date: day)
                         .joins(:occupation_type).where(occupation_types: { counts_as_working: true })
                         .includes(:shift, :user)
    scope = scope.where(department_id: department_ids) if department_ids.any?

    planned = Hash.new(0.0)
    users = {}
    scope.each do |entry|
      planned[entry.user_id] += entry.effective_duration_hours
      users[entry.user_id] ||= entry.user
    end
    [planned, users]
  end

  # Заявки-кандидаты: по подразделению со сменой в in_progress, попадающей в окно.
  # Нижняя граница на сутки назад ловит интервалы, начатые накануне и перешедшие
  # через полночь (обрезка по суткам делается сервисом).
  def candidate_job_ids(window)
    in_progress_id = RepairStatus.by_code(RepairStatus::IN_PROGRESS).id
    scope = RepairStatusChange
            .where(to_status_id: in_progress_id)
            .where(changed_at: (window.begin - 1.day)..window.end)
    if department_ids.any?
      scope = scope.joins(:service_job).where(service_jobs: { department_id: department_ids })
    end
    scope.distinct.pluck(:service_job_id)
  end

  def aggregate_seconds(segments)
    result = Hash.new { |hash, key| hash[key] = Hash.new(0.0) }
    segments.each { |seg| result[seg.user_id][seg.service_job_id] += seg.seconds }
    result
  end

  # job_id => user_id с максимальным in_progress-временем по этой заявке за день.
  def dominant_earner(seconds_by_user_job)
    best = {}
    seconds_by_user_job.each do |uid, jobs|
      jobs.each do |jid, secs|
        best[jid] = { uid: uid, secs: secs } if best[jid].nil? || secs > best[jid][:secs]
      end
    end
    best.transform_values { |value| value[:uid] }
  end

  # job_id => суммарная маржа работ, завершённых в этот день.
  def job_margins(job_ids, window)
    margins = Hash.new(0.0)
    return margins if job_ids.empty?

    RepairTask.includes(:repair_parts, device_task: :service_job)
              .where(device_tasks: { service_job_id: job_ids, done_at: window })
              .each { |task| margins[task.service_job.id] += task.margin if task.service_job }
    margins
  end

  def load_users(user_ids)
    return {} if user_ids.empty?

    User.where(id: user_ids).index_by(&:id)
  end
end
