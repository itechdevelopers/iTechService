class ServiceJobsMailer < ApplicationMailer

  def done_notice(service_job_id)
    @service_job = ServiceJob.find service_job_id
    mail to: @service_job.notification_email, subject: I18n.t('mail.service_jobs.done_notice.subject', device_type: @service_job.type_name)
  end

  def staff_notice(service_job_id, user_id, details={})
    @service_job = ServiceJob.find(service_job_id).decorate
    @user = User.find(user_id)
    @details = details
    subcribers_emails = @service_job.subscribers.pluck(:email).compact
    if subcribers_emails.any?
      mail to: subcribers_emails, subject: I18n.t('service_jobs_mailer.staff_notice.subject', device: @service_job.device_name)
    end
  end
end