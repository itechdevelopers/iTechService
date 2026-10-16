# frozen_string_literal: true

# «Кря-контроль»: анти-рейтинг «кто забывает брать устройство в работу».
#
# Считает по каждому технарю, сколько работ за месяц «догнал айс» — то есть
# по скольким работам есть маркер RepairAttentionMarker, по которому уведомление
# реально ушло (`notified_at` присутствует), а работа так и не была взята
# (`processed_action` не 'started', включая NULL = проигнорировал). Период
# фильтруется по `viewed_at`.
#
# Единица счёта — пара «сотрудник × работа» в месяце, а не маркер: анти-спам
# окно при создании маркера (RepairAttentionMarker::ANTI_SPAM_WINDOW) всего
# 10 минут, поэтому повторные открытия одной работы плодят маркеры — они
# засчитываются один раз.
#
# Строки разделены на две группы (обе — активные сотрудники любой роли):
#   primary_rows  — те, кто СЕЙЧАС на ремонтной локации (code repair*), включая 0;
#   extended_rows — НЕ на ремонте, но с ≥1 засчитанной работой за период
#                   (ушедшие с ремонта / зашедшие «мимо»); в UI изначально скрыты.
# Сортировка в обеих группах: count desc, затем имя.
class QuackControlQuery
  # @param month [Date] любой день внутри нужного месяца (по умолчанию текущий)
  def initialize(month = Date.current)
    @month_start = month.beginning_of_month.beginning_of_day
    @month_end = month.end_of_month.end_of_day
  end

  # @return [Array<Hash>] активные на ремонтной локации (включая 0) — основная таблица
  def primary_rows
    build_rows(repair_users)
  end

  # @return [Array<Hash>] активные НЕ на ремонте, но с ≥1 работой — расширенная (скрытая) часть
  def extended_rows
    extended_ids = counts.keys - repair_users.map(&:id)
    build_rows(User.active.where(id: extended_ids))
  end

  # @return [Integer] всего засчитанных работ за месяц (сумма по всем технарям,
  #   включая уволенных — их нет в таблице, но в итог месяца они входят)
  def total
    counts.values.sum
  end

  # @return [Array<Integer>] 3 числа — разбивка по декадам месяца [1–10, 11–20, 21–конец].
  #   Работа попадает в декаду своего первого засчитанного открытия в месяце.
  #   3-я декада поглощает 31-й день (clamp к индексу 2).
  def decade_counts
    buckets = [0, 0, 0]
    markers_by_job.each_value do |markers|
      first_viewed_at = markers.first[2]
      buckets[[(first_viewed_at.day - 1) / 10, 2].min] += 1
    end
    buckets
  end

  # @return [Hash{Integer => Array<Hash>}] расшифровка цифры: user_id =>
  #   [{ service_job:, first_viewed_at:, views:, outcomes: }], свежие сверху.
  #   views — сколько засчитанных маркеров дала работа (в счёт идёт 1);
  #   outcomes — их processed_action по порядку без повторов (nil = без ответа).
  def details
    @details ||= begin
      jobs = ServiceJob.includes(:item).where(id: markers_by_job.keys.map(&:last)).index_by(&:id)
      entries = markers_by_job.map do |(user_id, job_id), markers|
        { user_id: user_id,
          service_job: jobs[job_id],
          first_viewed_at: markers.first[2],
          views: markers.size,
          outcomes: markers.map(&:last).uniq }
      end
      entries.sort_by { |entry| -entry[:first_viewed_at].to_i }.group_by { |entry| entry[:user_id] }
    end
  end

  # Засчитанные за месяц маркеры одной строки расшифровки — их целиком
  # исключают из счёта (QuackControlController#exclude).
  def counted_markers(user_id:, service_job_id:)
    base_scope.where(user_id: user_id, service_job_id: service_job_id)
  end

  private

  # Общая выборка-метрика: айс догнал (notified_at есть), в работу не взяли
  # (processed_action != 'started'), момент открытия (viewed_at) — внутри месяца,
  # маркер не исключён из счёта вручную. Один источник правды для rows / total /
  # decade_counts / details.
  def base_scope
    RepairAttentionMarker
      .where.not(notified_at: nil)
      .where("repair_attention_markers.processed_action IS DISTINCT FROM ?", 'started')
      .where(viewed_at: @month_start..@month_end)
      .where(quack_excluded_at: nil)
  end

  # { user_id => число разных работ } — та же метрика, сгруппированная по технарю
  def counts
    @counts ||= base_scope.group(:user_id).distinct.count(:service_job_id)
  end

  # { [user_id, service_job_id] => [[user_id, service_job_id, viewed_at, processed_action], ...] }
  # Маркеры внутри пары — по времени открытия. Берём pluck, а не сгруппированный
  # minimum: тот отдаёт голый UTC Time без перевода в Time.zone, и утро 1-го числа
  # по местному времени читалось бы как 30-е/31-е.
  def markers_by_job
    @markers_by_job ||= base_scope.order(:viewed_at)
                                  .pluck(:user_id, :service_job_id, :viewed_at, :processed_action)
                                  .group_by { |user_id, job_id, *| [user_id, job_id] }
  end

  # Активные сотрудники, чья текущая локация — любая ремонтная (code LIKE 'repair%')
  def repair_users
    @repair_users ||= User.active
                          .joins(:location)
                          .where("locations.code LIKE ?", 'repair%')
                          .to_a
  end

  # Общий билдер: собирает [{ user:, count:, details: }] и сортирует count desc, затем имя.
  def build_rows(users)
    users.map { |user| { user: user, count: counts.fetch(user.id, 0), details: details.fetch(user.id, []) } }
         .sort_by { |row| [-row[:count], row[:user].short_name.to_s.downcase] }
  end
end
