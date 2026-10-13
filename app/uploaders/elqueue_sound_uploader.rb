# frozen_string_literal: true

class ElqueueSoundUploader < CarrierWave::Uploader::Base
  storage :fog

  # Вне прода в пути есть окружение: dev и staging могут смотреть в тот же бакет,
  # и запись с совпавшим id иначе перезаписала бы ту, что звучит на ТВ в магазине.
  def store_dir
    ['uploads/elqueue_sound', (Rails.env unless Rails.env.production?), model.id].compact.join('/')
  end

  # extension_allowlist, НЕ extension_white_list: имя из CarrierWave 1.x на
  # версии 2.2.2 молча игнорируется, и проверки расширения просто нет.
  def extension_allowlist
    %w[wav mp3]
  end

  def content_type_allowlist
    [%r{\Aaudio/}]
  end

  # ТВ держит в памяти все записи разом, а фраза длиной в пару секунд даже в
  # несжатом WAV занимает сотни килобайт.
  def size_range
    1..2.megabytes
  end

  private

  # Стандартное сообщение перечисляет разрешённые типы, а у нас вместо списка
  # регулярка — в форме она выглядела бы как «Разрешены: (?-mix:\Aaudio\/)».
  def check_content_type_whitelist!(new_file)
    super
  rescue CarrierWave::IntegrityError
    raise CarrierWave::IntegrityError, I18n.t('elqueue_sounds.errors.not_audio')
  end
end
