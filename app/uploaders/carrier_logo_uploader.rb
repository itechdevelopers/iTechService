class CarrierLogoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :file

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  # Оригинал ужимаем сразу: логотип скачивают из интернета в любом размере,
  # а крупнее, чем показывает список операторов, он нигде не нужен.
  process resize_to_limit: [400, 400]

  # Для строки выбора оператора: 48×18 на экране, запас ×2 под ретину.
  version :small do
    process resize_to_fit: [96, 36]
  end

  # Именно extension_allowlist: на CarrierWave 2.2.2 старое имя extension_white_list
  # молча игнорируется, и проверка расширения не работает вовсе.
  def extension_allowlist
    %w[jpg jpeg gif png]
  end
end
