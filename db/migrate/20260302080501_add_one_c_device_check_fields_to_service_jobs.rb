class AddOneCDeviceCheckFieldsToServiceJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :service_jobs, :one_c_device_check_status, :integer
    add_column :service_jobs, :one_c_device_checked_at, :datetime
    add_column :service_jobs, :one_c_device_check_error, :string
  end
end
