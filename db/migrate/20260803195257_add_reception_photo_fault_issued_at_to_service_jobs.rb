class AddReceptionPhotoFaultIssuedAtToServiceJobs < ActiveRecord::Migration[5.1]
  def change
    add_column :service_jobs, :reception_photo_fault_issued_at, :datetime
  end
end
