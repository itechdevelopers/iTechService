# frozen_string_literal: true

# Загруженная запись одной фразы для озвучки вызова на ТВ электронной очереди.
# Общая для всех очередей: фраза звучит одинаково, в какой бы очереди ни вызвали
# талон. Фразы без записи здесь звучат встроенными файлами из
# app/assets/audios/notifications.
class ElqueueSound < ApplicationRecord
  KINDS = %w[abbreviation number window].freeze

  mount_uploader :audio, ElqueueSoundUploader

  before_validation { self.value = value.to_s.strip }

  validates :kind, inclusion: { in: KINDS }
  validates :value, presence: true, uniqueness: { scope: :kind }
  validates :audio, presence: true

  # Текст, который звучит в записи: им фраза подписана на странице загрузки.
  def phrase
    case kind
    when 'abbreviation' then "Талон #{value}"
    when 'window' then "Окно номер #{value}"
    else value
    end
  end
end
