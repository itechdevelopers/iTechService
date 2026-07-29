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
# - Смена в графике за день — обязательное условие для ЛЮБОЙ строки.
# - Основная секция (`:rows`) = технари в графике И привязанные (users.location_id)
#   к локации «Ремонт» (code 'repair').
# - Дополнительная секция (`:extra_rows`) = технари в графике И с in_progress-временем,
#   но НЕ привязанные к «Ремонту» — «сделали ремонт вне своей локации».
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

    planned_hours, scheduled_users, shift_windows = scheduled_technicians(day)

    job_ids = candidate_job_ids(window)
    # Вручную исключённые заявки (excluded_from_reports) убираем из расчёта и
    # уводим в сноску внизу (решение 29.07.2026).
    excluded_jobs = ServiceJob.where(id: job_ids, excluded_from_reports: true)
                              .order(:ticket_number).to_a
    job_ids -= excluded_jobs.map(&:id)
    result[:excluded_jobs] = excluded_jobs.map { |job| { id: job.id, presentation: job.presentation } }

    durations = InProgressDurationService.call(service_job_ids: job_ids, window: window)
    # Реальное рабочее время: каждый сегмент in_progress обрезаем по окну смены его
    # автора. Так ночь и простой после ухода (device остаётся в in_progress, но никто
    # не работает) не попадают в зачёт. Заявка, начатая вчера и закрытая сегодня,
    # разбивается по сменам: вчерашняя часть — вчера, сегодняшняя — сегодня.
    # Деньги при этом уходят в день закрытия работы (см. job_margins).
    seconds_by_user_job = shift_clipped_seconds(durations.all_segments, shift_windows)

    involved_job_ids = seconds_by_user_job.values.flat_map(&:keys).uniq
    job_ticket = ServiceJob.where(id: involved_job_ids).pluck(:id, :ticket_number).to_h
    job_margin = job_margins(involved_job_ids, window)
    job_earner = dominant_earner(seconds_by_user_job)

    # Универсум строк — только сотрудники со сменой в графике за этот день.
    # Основная секция — привязанные к «Ремонту»; дополнительная — вне «Ремонта», но
    # накопившие in_progress-время. Смена обязательна для обеих.
    scheduled_ids = scheduled_users.keys
    repair_ids = repair_location_user_ids
    main_ids = scheduled_ids & repair_ids
    extra_ids = (scheduled_ids & seconds_by_user_job.keys) - repair_ids

    build = lambda do |uid|
      build_row(uid, scheduled_users[uid], planned_hours[uid] || 0.0,
                seconds_by_user_job[uid] || {}, job_ticket, job_margin, job_earner)
    end

    result[:day] = day
    result[:rows] = main_ids.map(&build).sort_by { |row| row[:name].to_s }
    result[:extra_rows] = extra_ids.map(&build).sort_by { |row| row[:name].to_s }
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

  # Рабочие смены за день → планов. часы (user_id => часы), объекты (user_id => User)
  # и окна смен (user_id => [Range<Time>, ...]) для обрезки in_progress-времени.
  def scheduled_technicians(day)
    scope = ScheduleEntry.where(date: day)
                         .joins(:occupation_type).where(occupation_types: { counts_as_working: true })
                         .includes(:shift, :user)
    scope = scope.where(department_id: department_ids) if department_ids.any?

    planned = Hash.new(0.0)
    users = {}
    windows = Hash.new { |hash, key| hash[key] = [] }
    midnight = Time.zone.local(day.year, day.month, day.day)
    scope.each do |entry|
      planned[entry.user_id] += entry.effective_duration_hours
      users[entry.user_id] ||= entry.user
      window = shift_window(entry, midnight)
      windows[entry.user_id] << window if window
    end
    [planned, users, windows]
  end

  # Конкретное окно смены (Range<Time>) на дату. Строим в `Time.zone` (город пользователя,
  # напр. Владивосток) — в той же зоне грузятся `changed_at` сегментов, поэтому пересечение
  # корректно. НЕ через `to_time(:local)`: OS-зона машины может отличаться от Time.zone
  # (на dev расходится на 7 ч), и окно уехало бы мимо сегментов. См. паттерн
  # ScheduleEntry#schedule_today_finalization (Time.zone.local(...) + seconds).
  def shift_window(entry, midnight)
    start_seconds = entry.effective_start_seconds
    end_seconds = entry.effective_end_seconds
    return nil unless start_seconds && end_seconds && end_seconds > start_seconds

    (midnight + start_seconds.seconds)..(midnight + end_seconds.seconds)
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

  # user_id => { service_job_id => секунды }, где каждый сегмент in_progress обрезан по
  # окну(ам) смены его автора. Сегмент целиком вне смены (ночь / после ухода) даёт 0 и
  # отсеивается. Заявка через полночь даёт по сегменту на каждый день → время делится.
  def shift_clipped_seconds(segments, shift_windows)
    result = Hash.new { |hash, key| hash[key] = Hash.new(0.0) }
    segments.each do |seg|
      shift_windows[seg.user_id].each do |window|
        low = [seg.started_at, window.begin].max
        high = [seg.ended_at, window.end].min
        result[seg.user_id][seg.service_job_id] += (high - low).to_f if high > low
      end
    end
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

  # ID активных сотрудников, привязанных (users.location_id) к локации «Ремонт»
  # выбранных подразделений. Только code 'repair' — repairmac/repair_notebooks на
  # проде не используются (см. Location::CODES, решение заказчика 27.07.2026).
  def repair_location_user_ids
    scope = Location.repair
    scope = scope.in_department(department_ids) if department_ids.any?
    User.active.located_at(scope.pluck(:id)).pluck(:id)
  end
end
