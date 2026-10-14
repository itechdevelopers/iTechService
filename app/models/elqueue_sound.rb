# frozen_string_literal: true

# Загруженная запись одной фразы для озвучки вызова на ТВ электронной очереди.
# Общая для всех очередей: фраза звучит одинаково, в какой бы очереди ни вызвали
# талон. Фразы без записи здесь звучат встроенными файлами из
# app/assets/audios/notifications.
class ElqueueSound < ApplicationRecord
  KINDS = %w[abbreviation number window].freeze
  # ТВ произносит число талона кусками: до 19 целиком, дальше десятки + единицы.
  NUMBER_VALUES = ((1..19).to_a + (20..90).step(10).to_a).map(&:to_s).freeze
  BUILTIN_DIRS = {
    'abbreviation' => 'abbreviations',
    'number' => 'numbers',
    'window' => 'windows'
  }.freeze

  # Одна строка на странице загрузки: фраза, которая может прозвучать на ТВ.
  Phrase = Struct.new(:kind, :value, :sound, :in_use) do
    def text
      ElqueueSound.phrase_for(kind, value)
    end

    def builtin_asset
      ElqueueSound.builtin_asset(kind, value)
    end
  end

  mount_uploader :audio, ElqueueSoundUploader

  before_validation { self.value = value.to_s.strip }

  validates :kind, inclusion: { in: KINDS }
  validates :value, presence: true, uniqueness: { scope: :kind }
  validates :value, inclusion: { in: NUMBER_VALUES }, if: -> { kind == 'number' }
  validates :value, format: { with: /\A[1-9]\d*\z/ }, if: -> { kind == 'window' }
  validates :audio, presence: true

  def self.phrase_for(kind, value)
    case kind
    when 'abbreviation' then "Талон #{value}"
    when 'window' then "Окно номер #{value}"
    else value
    end
  end

  # Встроенные файлы названы ровно тем, что в них звучит, поэтому имя файла и
  # есть текст фразы. nil — встроенной записи для фразы нет.
  def self.builtin_asset(kind, value)
    logical_path = "notifications/#{BUILTIN_DIRS.fetch(kind)}/#{phrase_for(kind, value)}.wav"
    logical_path if Rails.root.join('app/assets/audios', logical_path).exist?
  end

  def self.builtin_values(kind)
    prefix = phrase_for(kind, '')
    Dir[Rails.root.join('app/assets/audios/notifications', BUILTIN_DIRS.fetch(kind), '*.wav')]
      .map { |path| File.basename(path, '.wav').delete_prefix(prefix) }
  end

  # Всё, что ТВ может проиграть: загруженные записи и встроенные файлы, которые
  # ничем не заменены. От настроек очередей не зависит, чтобы прозвучал и талон
  # пункта, который заархивировали, пока по нему ещё ждали.
  def self.playable
    uploaded = all.index_by { |sound| [sound.kind, sound.value] }
    builtin = KINDS.flat_map { |kind| builtin_values(kind).map { |value| [kind, value] } }
    (uploaded.keys | builtin).map { |kind, value| Phrase.new(kind, value, uploaded[[kind, value]]) }
  end

  # Все фразы, которые могут прозвучать на ТВ, сгруппированные по виду. Загруженная
  # запись фразы, которой больше нет в очередях, тоже в списке — иначе её
  # не удалить.
  def self.phrases
    uploaded = all.group_by(&:kind)
    needed = {
      'abbreviation' => QueueItem.where(archived: false).where.not(ticket_abbreviation: [nil, ''])
                                 .distinct.pluck(:ticket_abbreviation).map(&:strip),
      'number' => NUMBER_VALUES,
      'window' => (1..ElectronicQueue.maximum(:windows_count).to_i).map(&:to_s)
    }

    KINDS.each_with_object({}) do |kind, result|
      sounds = (uploaded[kind] || []).index_by(&:value)
      values = (needed[kind] | sounds.keys).sort_by { |value| kind == 'abbreviation' ? value : value.to_i }
      result[kind] = values.map { |value| Phrase.new(kind, value, sounds[value], needed[kind].include?(value)) }
    end
  end

  def phrase
    self.class.phrase_for(kind, value)
  end
end
