# encoding: utf-8

class UniformKindUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :file

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  permissions 0777

  version :thumb do
    process resize_to_fill: [120, 120]
  end

  # Именно extension_allowlist: на CarrierWave 2.2.2 старое имя extension_white_list
  # молча игнорируется, и проверка расширения не работает вовсе.
  def extension_allowlist
    %w[jpg jpeg gif png]
  end
end
