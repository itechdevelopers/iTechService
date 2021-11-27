class DailySalesReportMailingJob < ApplicationJob
  queue_as :reports

  def perform
    report = DailySalesReport.new
    report.call
    ReportsMailer.daily_sales(report).deliver_now
  end
end
