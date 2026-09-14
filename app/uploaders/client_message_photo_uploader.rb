# frozen_string_literal: true

# Фото из переписки с клиентом. Без MiniMagick: Telegram уже пережал картинку
# на стороне клиента, обрабатывать нечего.
class ClientMessagePhotoUploader < CarrierWave::Uploader::Base
  storage :fog

  def store_dir
    "uploads/client_message/#{model.id}"
  end

  # extension_allowlist, НЕ extension_white_list: имя из CarrierWave 1.x на
  # версии 2.2.2 молча игнорируется, и проверки расширения просто нет.
  def extension_allowlist
    %w[jpg jpeg png webp]
  end

  # marcel определяет тип по сигнатуре файла, а не по имени.
  def content_type_allowlist
    [%r{\Aimage/}]
  end
end
