class RemnantsReportMailingJob < ApplicationJob
  include Rails.application.routes.url_helpers
  queue_as :reports

  def perform
    report = FewRemnantsReport.new(kind: :spare_parts)
    report.call
    ReportsMailer.few_remnants(report).deliver_now
  end
end
