# frozen_string_literal: true

# Персональная настройка одного типа уведомления. Строка существует только у
# того, кто что-то менял: её отсутствие означает «как в каталоге», поэтому
# читать настройку надо через .for / .map_for — они возвращают незаписанный
# объект с дефолтами, и вызывающий код не различает эти два случая.
class UserNotificationPreference < ApplicationRecord
  MAX_REPEATS = 10
  # Шаг мельче минуты бессмысленен, крупнее десяти — уже не «напоминание».
  REPEAT_INTERVALS = (1..10).freeze
  DEFAULT_INTERVAL = 5

  belongs_to :user

  validates :type_key, presence: true,
                       inclusion: { in: ->(_record) { NotificationCatalog.keys } },
                       uniqueness: { scope: :user_id }
  validates :color, inclusion: { in: NotificationCatalog::COLORS }
  validates :repeat_count, inclusion: { in: (0..MAX_REPEATS) }
  validates :repeat_interval_minutes, inclusion: { in: REPEAT_INTERVALS }
  validate :repeats_fit_window

  def self.for(user, type_key)
    entry = NotificationCatalog[type_key]
    return nil if entry.nil?

    find_by(user_id: user.id, type_key: entry.key) || default_for(user, entry)
  end

  # Настройки сразу по многим типам — одним запросом. Поповер рисует десятки
  # уведомлений за раз, и поштучное чтение дало бы запрос на строку.
  def self.map_for(user, type_keys = NotificationCatalog.keys)
    saved = where(user_id: user.id, type_key: type_keys).index_by(&:type_key)

    type_keys.each_with_object({}) do |key, result|
      entry = NotificationCatalog[key]
      next if entry.nil?

      result[key] = saved[key] || default_for(user, entry)
    end
  end

  def self.default_for(user, entry)
    new(user: user,
        type_key: entry.key,
        in_app: entry.default_channel?(:in_app),
        telegram: entry.default_channel?(:telegram),
        color: entry.default_color,
        bold: entry.default_bold,
        repeat_count: 0,
        repeat_interval_minutes: DEFAULT_INTERVAL)
  end

  # Сохраняем только отличия от каталога: настройка, совпавшая с дефолтом,
  # удаляется. Иначе у каждого сотрудника осело бы по строке на каждый тип, и
  # правка дефолта в каталоге перестала бы до них доходить.
  def self.apply(user, type_key, attrs)
    entry = NotificationCatalog[type_key]
    return nil if entry.nil?

    preference = self.for(user, type_key)
    preference.assign_attributes(attrs)

    if preference.matches_default?
      preference.destroy if preference.persisted?
      return preference
    end

    preference.save
    preference
  end

  def matches_default?
    default = self.class.default_for(user, entry)

    %i[in_app telegram color bold repeat_count repeat_interval_minutes].all? do |field|
      public_send(field) == default.public_send(field)
    end
  end

  def entry
    @entry ||= NotificationCatalog[type_key]
  end

  # Канал, которого тип не умеет, выключен независимо от настройки: у обязательных
  # типов заглушить оба канала нельзя, но выбрать один из них — можно.
  def deliver?(channel)
    return false unless entry&.supports?(channel)
    return entry.default_channel?(channel) if entry.mandatory && silenced?

    public_send(channel)
  end

  def silenced?
    !in_app && !telegram
  end

  def repeats?
    repeat_count.to_i.positive?
  end

  private

  # Повторы не должны переживать событие, ради которого они шлются: у «фото при
  # приёмке» окно до дедлайна — полчаса, и десять напоминаний по десять минут
  # пришли бы уже после того, как минус выставлен.
  def repeats_fit_window
    window = entry&.repeat_window_minutes
    return if window.nil? || !repeats?

    total = repeat_count * repeat_interval_minutes
    return if total <= window

    errors.add(:repeat_count,
               "не укладываются в #{window} мин: #{repeat_count} × " \
               "#{repeat_interval_minutes} мин = #{total} мин")
  end
end
