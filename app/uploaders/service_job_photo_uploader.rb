class ServiceJobPhotoUploader < ApplicationUploader
  permissions 0777

  process resize_to_limit: [600, 600]

  version :thumb do
    process resize_and_pad: [150, 200]
  end
end