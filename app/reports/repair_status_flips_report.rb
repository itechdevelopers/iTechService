# frozen_string_literal: true

# Отчёт по «качелям статуса»: технари, обходящие «Строгий ремонт» сменой статуса
# `* → in_progress → (прочитал) → waiting` быстрее порога. Read-only проекция той же
# логики, что и детект в ServiceJob#change_repair_status! (см. §3.1 фичи).
# За period находит все закрывающие смены `in_progress → waiting`, к каждой одним
# индексным SELECT берёт предыдущую смену и проверяет, что это та же пара тем же юзером
# в пределах Setting.repair_status_flip_seconds. См. docs/repair-status-flip-detection-feature.md.
class RepairStatusFlipsReport < BaseReport
  ReportRecord = Struct.new(:time, :job_id, :ticket_number, :technician, :duration)

  def call
    waiting_id     = RepairStatus.by_code(RepairStatus::WAITING).id
    in_progress_id = RepairStatus.by_code(RepairStatus::IN_PROGRESS).id
    threshold      = flip_threshold

    closings = RepairStatusChange
               .includes(:user, :service_job)
               .where(changed_at: period, from_status_id: in_progress_id, to_status_id: waiting_id)
    if department_ids.any?
      closings = closings.joins(:service_job).where(service_jobs: { department_id: department_ids })
    end

    records = closings.map do |closing|
      opening = preceding_change(closing)
      next unless opening&.to_status_id == in_progress_id
      next unless opening.user_id == closing.user_id

      delta = closing.changed_at - opening.changed_at
      next if delta >= threshold

      ReportRecord.new(
        closing.changed_at,
        closing.service_job_id,
        closing.service_job.ticket_number,
        closing.user&.short_name,
        delta
      )
    end.compact

    result[:records] = records.sort_by(&:time).reverse
  end

  private

  # Непосредственно предыдущая смена статуса той же работы (та же выборка, что и в
  # ServiceJob#detect_repair_status_flip!) — один индексный SELECT по changed_at.
  def preceding_change(closing)
    RepairStatusChange
      .where(service_job_id: closing.service_job_id)
      .where('changed_at <= ?', closing.changed_at)
      .where.not(id: closing.id)
      .order(changed_at: :desc, id: :desc)
      .first
  end

  def flip_threshold
    seconds = Setting.repair_status_flip_seconds
    seconds <= 0 ? 300 : seconds
  end
end
