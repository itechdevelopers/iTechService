# frozen_string_literal: true

# «Кря-контроль»: анти-рейтинг «кто забывает брать устройство в работу».
#
# Считает по каждому технарю, сколько раз его «догнал айс» за месяц — то есть
# сколько маркеров RepairAttentionMarker, по которым уведомление реально ушло
# (`notified_at` присутствует), а работа так и не была взята (`processed_action`
# не 'started', включая NULL = проигнорировал). Период фильтруется по `viewed_at`.
#
# Строки = только активные технари (роль technician): на текущей ремонтной локации
# (code repair*) + те, у кого за период был хотя бы один засчитанный маркер
# (на случай ухода с ремонта). Сортировка: count desc, затем имя.
class QuackControlQuery
  # @param month [Date] любой день внутри нужного месяца (по умолчанию текущий)
  def initialize(month = Date.current)
    @month_start = month.beginning_of_month.beginning_of_day
    @month_end = month.end_of_month.end_of_day
  end

  # @return [Array<Hash>] [{ user: User, count: Integer }, ...]
  def rows
    counts = marker_counts
    users = relevant_users(counts.keys).index_by(&:id)

    users.values
         .map { |user| { user: user, count: counts.fetch(user.id, 0) } }
         .sort_by { |row| [-row[:count], row[:user].short_name.to_s.downcase] }
  end

  private

  # { user_id => count } — айс догнал (notified_at есть), но в работу не взяли
  def marker_counts
    RepairAttentionMarker
      .where.not(notified_at: nil)
      .where("repair_attention_markers.processed_action IS DISTINCT FROM ?", 'started')
      .where(viewed_at: @month_start..@month_end)
      .group(:user_id)
      .count
  end

  # Только технари (роль technician): и текущие на ремонте, и «нагрешившие» за период.
  def relevant_users(user_ids_with_markers)
    User.active.technician.where(id: repair_technician_ids | user_ids_with_markers)
  end

  # Активные технари, чья текущая локация — любая ремонтная (code LIKE 'repair%')
  def repair_technician_ids
    User.active.technician
        .joins(:location)
        .where("locations.code LIKE ?", 'repair%')
        .pluck(:id)
  end
end
