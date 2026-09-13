# frozen_string_literal: true

module ClientChat
  # Цветной кружок к названию города для клавиатуры бота.
  #
  # Цвет берём из справочника городов — тот же, которым город подсвечен в
  # расписаниях. При появлении нового города список править не нужно, и цвет
  # в боте совпадает с цветом внутри Айса.
  module CityMark
    FALLBACK = '🔵'

    # Границы тона (H в HSV) и соответствующий кружок. Сравниваем именно тон,
    # а не расстояние в RGB: тёмно-синий #002773 по RGB ближе к чёрному, чем
    # к синему, и город получил бы ⚫ вместо ожидаемого 🔵.
    HUES = [
      [15,  '🔴'],
      [45,  '🟠'],
      [70,  '🟡'],
      [160, '🟢'],
      [260, '🔵'],
      [320, '🟣'],
      [360, '🔴']
    ].freeze

    # Ниже этой насыщенности тона уже нет — остаётся серая шкала.
    GREY_SATURATION = 0.15
    # Тёмный тёплый цвет читается как коричневый, а не как оранжевый.
    BROWN_VALUE = 0.55
    # Граница между тёмно-серым и светло-серым: середина шкалы выглядит скорее
    # тёмной, поэтому порог выше 0.5.
    GREY_SPLIT = 0.6

    def self.for(city)
      rgb = parse(city&.color)
      return FALLBACK if rgb.nil?

      hue, saturation, value = to_hsv(rgb)
      return value < GREY_SPLIT ? '⚫' : '⚪' if saturation < GREY_SATURATION
      return '🟤' if hue.between?(15, 45) && value < BROWN_VALUE

      HUES.find { |bound, _| hue < bound }&.last || FALLBACK
    end

    # Цвет хранится строкой вида "#002773"; сокращённую запись "#07f" тоже
    # принимаем — в справочнике встречается и та, и другая.
    def self.parse(color)
      hex = color.to_s.strip.delete_prefix('#')
      hex = hex.chars.flat_map { |c| [c, c] }.join if hex.length == 3
      return nil unless hex.length == 6 && hex.match?(/\A\h{6}\z/)

      hex.scan(/../).map { |part| part.to_i(16) }
    end

    def self.to_hsv(rgb)
      r, g, b = rgb.map { |c| c / 255.0 }
      max = [r, g, b].max
      min = [r, g, b].min
      delta = max - min

      hue =
        if delta.zero? then 0.0
        elsif max == r then 60 * (((g - b) / delta) % 6)
        elsif max == g then 60 * (((b - r) / delta) + 2)
        else 60 * (((r - g) / delta) + 4)
        end

      [hue, max.zero? ? 0.0 : delta / max, max]
    end

    private_class_method :parse, :to_hsv
  end
end
