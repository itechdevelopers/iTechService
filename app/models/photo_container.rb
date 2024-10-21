class PhotoContainer < ApplicationRecord
  include Auditable
  has_one :service_job

  mount_uploaders :reception_photos, ServiceJobPhotoUploader
  mount_uploaders :in_operation_photos, ServiceJobPhotoUploader
  mount_uploaders :completed_photos, ServiceJobPhotoUploader
  audited associated_with: :service_job
end
