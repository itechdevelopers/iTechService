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
    first_viewed_at_by_job.each_value do |viewed_at|
      buckets[[(viewed_at.day - 1) / 10, 2].min] += 1
    end
    buckets
  end

  private

  # Общая выборка-метрика: айс догнал (notified_at есть), в работу не взяли
  # (processed_action != 'started'), момент открытия (viewed_at) — внутри месяца.
  # Один источник правды для rows / total / decade_counts.
  def base_scope
    RepairAttentionMarker
      .where.not(notified_at: nil)
      .where("repair_attention_markers.processed_action IS DISTINCT FROM ?", 'started')
      .where(viewed_at: @month_start..@month_end)
  end

  # { user_id => число разных работ } — та же метрика, сгруппированная по технарю
  def counts
    @counts ||= base_scope.group(:user_id).distinct.count(:service_job_id)
  end

  # { [user_id, service_job_id] => самый ранний viewed_at в месяце }
  # Сгруппированный minimum (в отличие от pluck) отдаёт голый UTC Time без перевода
  # в Time.zone: без in_time_zone утро 1-го числа по местному времени читалось бы
  # как 30-е/31-е и уезжало в 3-ю декаду.
  def first_viewed_at_by_job
    base_scope.group(:user_id, :service_job_id).minimum(:viewed_at).transform_values(&:in_time_zone)
  end

  # Активные сотрудники, чья текущая локация — любая ремонтная (code LIKE 'repair%')
  def repair_users
    @repair_users ||= User.active
                          .joins(:location)
                          .where("locations.code LIKE ?", 'repair%')
                          .to_a
  end

  # Общий билдер: собирает [{ user:, count: }] и сортирует count desc, затем имя.
  def build_rows(users)
    users.map { |user| { user: user, count: counts.fetch(user.id, 0) } }
         .sort_by { |row| [-row[:count], row[:user].short_name.to_s.downcase] }
  end
end
