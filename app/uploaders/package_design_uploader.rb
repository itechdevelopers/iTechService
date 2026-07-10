# encoding: utf-8

class PackageDesignUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :file

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  permissions 0777

  version :thumb do
    process resize_to_fill: [120, 120]
  end

  # ВНИМАНИЕ: именно extension_allowlist, а не extension_white_list —
  # на CarrierWave 2.2.2 старое имя молча игнорируется (см. memory
  # project_carrierwave_extension_whitelist_broken).
  def extension_allowlist
    %w[jpg jpeg gif png]
  end
end
