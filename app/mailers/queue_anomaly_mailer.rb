class QueueAnomalyMailer < ApplicationMailer
  def anomaly_notification(anomalies)
    @anomalies = anomalies
    @detection_date = Date.current

    recipients = Setting.emails_for_queue_anomalies
    return if recipients.blank?

    mail to: recipients,
         subject: I18n.t('mail.queue_anomaly.subject', date: I18n.l(@detection_date, format: :short))
  end
end