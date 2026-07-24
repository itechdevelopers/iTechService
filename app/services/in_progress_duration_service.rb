# frozen_string_literal: true

# Считает время, проведённое заявками в статусе «в процессе ремонта» (in_progress),
# по данным repair_status_changes. Общее ядро для отчётов о работе технарей
# (см. docs/technicians-in-progress-reports-feature.md).
#
# Интервал in_progress = от смены статуса В in_progress до следующей смены статуса
# (любой). Незакрытый интервал (заявка всё ещё в in_progress) закрывается на `now`.
#
# `window` (Range Time..Time) опционален: если задан — интервалы обрезаются по его
# границам (нужно для суточного отчёта-таймлайна). Без него берётся полная
# длительность (нужно для отчёта медианы/среднего по видам работ).
class InProgressDurationService
  Segment = Struct.new(:service_job_id, :started_at, :ended_at, :user_id, keyword_init: true) do
    def seconds
      (ended_at - started_at).to_f
    end
  end

  def self.call(**kwargs)
    new(**kwargs).call
  end

  def initialize(service_job_ids:, window: nil, now: Time.current)
    @service_job_ids = Array(service_job_ids).uniq
    @window = window
    @now = now
  end

  def call
    @segments_by_job = build_segments
    self
  end

  # Суммарные секунды in_progress по заявке (в пределах window, если задан).
  def seconds_for(service_job_id)
    segments_for(service_job_id).sum(&:seconds)
  end

  def segments_for(service_job_id)
    @segments_by_job.fetch(service_job_id, [])
  end

  def all_segments
    @segments_by_job.values.flatten
  end

  private

  def in_progress_id
    @in_progress_id ||= RepairStatus.by_code(RepairStatus::IN_PROGRESS).id
  end

  def build_segments
    return {} if @service_job_ids.empty?

    result = Hash.new { |h, k| h[k] = [] }
    changes = RepairStatusChange
              .where(service_job_id: @service_job_ids)
              .order(:service_job_id, :changed_at, :id)
              .to_a

    changes.group_by(&:service_job_id).each do |job_id, job_changes|
      job_changes.each_with_index do |change, index|
        next unless change.to_status_id == in_progress_id

        started = change.changed_at
        succeeding = job_changes[index + 1]
        ended = succeeding ? succeeding.changed_at : @now

        segment = clip(job_id, started, ended, change.user_id)
        result[job_id] << segment if segment
      end
    end
    result
  end

  # Обрезает [started, ended] по границам window. Возвращает Segment либо nil,
  # если пересечения с window нет (или интервал вырожденный).
  def clip(job_id, started, ended, user_id)
    low  = @window ? [started, @window.begin].max : started
    high = @window ? [ended, @window.end].min : ended
    return nil if high <= low

    Segment.new(service_job_id: job_id, started_at: low, ended_at: high, user_id: user_id)
  end
end
