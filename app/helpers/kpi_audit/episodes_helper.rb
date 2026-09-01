# frozen_string_literal: true

module KpiAudit
  # Presentation helpers for the KPI audit screens.
  module EpisodesHelper
    def kpi_mode_description(mode)
      if mode.to_s == 'strict'
        'Строгий — дополнительно показывает эпизоды со слабыми и пограничными признаками.'
      else
        'Обычный — показывает только эпизоды с более существенными признаками нарушений.'
      end
    end

    def kpi_episode_reasons(episode)
      signals = episode.signals.reject { |signal| %w[multiple_kpi confirmed_ticket].include?(signal[:code].to_s) }
      ticket = episode.video_summary[:ticket_number]
      count = episode.visit_profile[:kpi_count].to_i
      if ticket.present? && count > 1
        description = "1 талон электронной очереди и #{count} #{kpi_operation_word(count)}, " \
                      'влияющих на выполнение плана, в рамках этого талона'
        signals.unshift(code: :visit_summary, description: description)
      end
      signals
    end

    def kpi_operation_word(count)
      return 'операция' if count % 10 == 1 && count % 100 != 11
      return 'операции' if (2..4).cover?(count % 10) && !(12..14).cover?(count % 100)

      'операций'
    end

    # rubocop:disable Metrics/AbcSize
    def kpi_free_service_reason(episode, signal)
      match = signal[:description].to_s.match(/\A(\d+) Бесплатных сервисов за/)
      return signal[:description] unless match

      entries = episode.timeline.select { |entry| entry[:type].to_s == 'free_service_created' && entry[:occurred_at] }
      return signal[:description].sub('Бесплатных', 'бесплатных') if entries.size < 2

      times = entries.map { |entry| entry[:occurred_at] }
      seconds = (times.max - times.min).round
      "#{match[1]} бесплатных сервисов за #{human_duration(seconds)}"
    end
    # rubocop:enable Metrics/AbcSize

    def human_duration(seconds)
      minutes, remainder = seconds.to_i.divmod(60)
      return "#{remainder} #{russian_seconds_word(remainder)}" if minutes.zero?

      "#{minutes} #{russian_minutes_word(minutes)} и #{remainder} #{russian_seconds_word(remainder)}"
    end

    def russian_seconds_word(value)
      return 'секунду' if value % 10 == 1 && value % 100 != 11
      return 'секунды' if (2..4).cover?(value % 10) && !(12..14).cover?(value % 100)

      'секунд'
    end

    def russian_minutes_word(value)
      return 'минуту' if value % 10 == 1 && value % 100 != 11
      return 'минуты' if (2..4).cover?(value % 10) && !(12..14).cover?(value % 100)

      'минут'
    end
  end
end
