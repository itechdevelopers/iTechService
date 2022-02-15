class ReportsMailer < ApplicationMailer
  include ApplicationHelper
  layout 'mailer'

  def few_remnants(report)
    @report = report
    recipients = Setting.emails_for_acts
    mail to: recipients, subject: I18n.t("reports.#{report.name}.title")
  end

  def daily_sales(report)
    @result = report.result
    mail to: Setting.emails_for_sales_report,
         subject: "Отчёт продаж день за #{I18n.l(report.date, format: :long)}"
  end
end
