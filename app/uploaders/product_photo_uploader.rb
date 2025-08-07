class ProductPhotoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :fog

  process :resize_and_pad_white

  version :thumb do
    process :resize_and_pad_white_small
  end

  def resize_and_pad_white
    manipulate! do |img|
      img.combine_options do |c|
        x = img[:width]
        y = img[:height]
        c.resize "#{x}x#{y}"
        c.background "#ffffff"
        c.gravity "Center"
        c.extent "#{x}x#{y}"
      end
      img
    end
  end

  def resize_and_pad_white_small
    manipulate! do |img|
      img.combine_options do |c|
        x = 120
        y = 160
        c.resize "#{x}x#{y}"
        c.background "#ffffff"
        c.gravity "Center"
        c.extent "#{x}x#{y}"
      end
      img
    end
  end

  def extension_allowlist
    %w(jpg jpeg gif png)
  end
end