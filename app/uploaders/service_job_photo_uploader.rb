class ServiceJobPhotoUploader < ApplicationUploader
  permissions 0777

  process resize_and_pad_white: [750, 1000]

  version :thumb do
    process resize_and_pad_white: [30, 40]
  end

  def resize_and_pad_white(x, y)
    manipulate! do |img|
      img.combine_options do |c|
        c.resize "#{x}x#{y}"
        c.background "#ffffff"
        c.gravity "Center"
        c.extent "#{x}x#{y}"
      end
      img
    end
  end
end