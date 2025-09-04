class AddServiceJobIdToServiceSmsNotifications < ActiveRecord::Migration[5.1]
  def change
    add_column :service_sms_notifications, :service_job_id, :integer
    add_index :service_sms_notifications, :service_job_id
    add_foreign_key :service_sms_notifications, :service_jobs
  end
end
