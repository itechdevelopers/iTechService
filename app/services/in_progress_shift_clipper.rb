# frozen_string_literal: true

# Обрезает in_progress-сегменты по рабочим сменам их авторов: ночь и простой вне смены
# не засчитываются как время ремонта. Вариант A (решение 3, 29.07.2026): если у автора
# нет рабочей смены за день сегмента — сегмент отбрасывается целиком (образец без графика
# в норматив не идёт). См. docs/repair-time-standards-feature.md.
#
# Вход/выход — массив InProgressDurationService::Segment. Один сырой сегмент может дать
# несколько кусков (несколько смен за день или переход через полночь) либо ноль (вне смены).
# Окно смены строим в `Time.zone` (город пользователя), в той же зоне грузятся changed_at
# сегментов — иначе окно уедет мимо (грабля Отчёта 2: НЕ через to_time(:local)/OS-зону).
class InProgressShiftClipper
  Segment = InProgressDurationService::Segment

  def self.call(segments)
    new(segments).call
  end

  def initialize(segments)
    @segments = Array(segments)
  end

  def call
    return [] if @segments.empty?

    windows = build_windows
    @segments.flat_map { |segment| clip(segment, windows) }
  end

  private

  # { [user_id, Date] => [Range<Time>, ...] } — рабочие смены в Time.zone.
  def build_windows
    pairs = @segments.flat_map { |seg| dates_of(seg).map { |date| [seg.user_id, date] } }.uniq
    user_ids = pairs.map(&:first).compact.uniq
    return {} if user_ids.empty?

    windows = Hash.new { |hash, key| hash[key] = [] }
    ScheduleEntry.where(user_id: user_ids, date: pairs.map(&:last).uniq)
                 .joins(:occupation_type).where(occupation_types: { counts_as_working: true })
                 .each do |entry|
      window = window_for(entry)
      windows[[entry.user_id, entry.date]] << window if window
    end
    windows
  end

  def dates_of(segment)
    (segment.started_at.to_date..segment.ended_at.to_date).to_a
  end

  def window_for(entry)
    start_seconds = entry.effective_start_seconds
    end_seconds = entry.effective_end_seconds
    return nil unless start_seconds && end_seconds && end_seconds > start_seconds

    midnight = Time.zone.local(entry.date.year, entry.date.month, entry.date.day)
    (midnight + start_seconds.seconds)..(midnight + end_seconds.seconds)
  end

  # Пересечения сегмента с окнами смен по всем его дням. Пусто → сегмент вне смены (Вариант A).
  def clip(segment, windows)
    dates_of(segment).flat_map do |date|
      windows[[segment.user_id, date]].filter_map do |window|
        low = [segment.started_at, window.begin].max
        high = [segment.ended_at, window.end].min
        next if high <= low

        Segment.new(service_job_id: segment.service_job_id, started_at: low,
                    ended_at: high, user_id: segment.user_id)
      end
    end
  end
end
