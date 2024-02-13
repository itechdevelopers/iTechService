class ServiceJobPhotoUploader < ApplicationUploader
  permissions 0777

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
        x = 60
        y = 80
        c.resize "#{x}x#{y}"
        c.background "#ffffff"
        c.gravity "Center"
        c.extent "#{x}x#{y}"
      end
      img
    end
  end
end