# frozen_string_literal: true

# Отчёт «Я сломал»: кто из сотрудников сломал устройство в процессе ремонта за
# период, с какими работами и на какую сумму запчастей. Стоимость берётся из
# снапшота BreakageReport#part_price — цена на момент установки запчасти взамен
# сломанной, а не текущая закупочная. См. docs/i-broke-it-feature.md.
class IBrokeItReport < BaseReport
  ReportRecord = Struct.new(:date, :job_id, :ticket_number, :device, :part, :part_price)

  def call
    reports = BreakageReport.includes(:user, :item, service_job: :item)
                            .where(created_at: period)
    reports = reports.in_department(department) if department

    groups = reports.group_by(&:user).map do |user, user_reports|
      rows = user_reports.sort_by(&:created_at).map { |report| build_record(report) }

      {
        user: user&.short_name,
        rows: rows,
        total: rows.sum { |row| row.part_price.to_f }
      }
    end

    result[:groups] = groups.sort_by { |group| -group[:total] }
    result[:total] = result[:groups].sum { |group| group[:total] }
    self
  end

  private

  def build_record(report)
    job = report.service_job

    ReportRecord.new(
      report.created_at,
      job&.id,
      job&.ticket_number,
      job&.device_short_name,
      report.item_presentation,
      report.part_price
    )
  end
end
