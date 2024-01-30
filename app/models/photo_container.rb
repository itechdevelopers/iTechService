class PhotoContainer < ApplicationRecord
  has_one :service_job

  mount_uploaders :reception_photos, ServiceJobPhotoUploader
  mount_uploaders :in_operation_photos, ServiceJobPhotoUploader
  mount_uploaders :completed_photos, ServiceJobPhotoUploader
end
