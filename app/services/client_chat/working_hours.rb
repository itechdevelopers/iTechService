# frozen_string_literal: true

module ClientChat
  # Открыт ли город прямо сейчас — по расписанию его подразделений, в его же
  # часовом поясе. Нужен автоответу: обращение может прийти ночью во
  # Владивостоке, когда сервер и залогиненный сотрудник живут в других поясах.
  #
  # Расписание в базе хранится у подразделений, поэтому за часами города идём
  # в первое его подразделение, где они заполнены: у бэк-офиса их обычно нет,
  # а торговые точки одного города работают по одному графику.
  class WorkingHours
    # Тот же запасной пояс, что в ScheduleEntry.
    DEFAULT_ZONE = 'Vladivostok'

    def self.open?(city, at: Time.current)
      new(city).open?(at)
    end

    def self.summary(city)
      new(city).summary
    end

    def initialize(city)
      @city = city
    end

    def open?(at = Time.current)
      # Город не определён — молчим: автоответ с чужими часами хуже молчания.
      return true if @city.nil?

      local = at.in_time_zone(zone)
      row = row_for(local.to_date)
      return true if row.nil?
      return false if row.is_closed?
      # Часы не заполнены — тоже считаем открытым: ложное «мы закрыты» хуже,
      # чем отсутствие автоответа.
      return true if row.opens_at.blank? || row.closes_at.blank?

      # Сравниваем "ЧЧ:ММ" строками: колонки типа time Rails хранит как время
      # 2000-01-01, и арифметика с сегодняшней датой требовала бы лишних
      # преобразований. Окон, переходящих через полночь, у филиалов не бывает.
      now = local.strftime('%H:%M')
      now >= row.opens_at.strftime('%H:%M') && now <= row.closes_at.strftime('%H:%M')
    end

    # «Пн-Пт 10:00-20:00, Сб-Вс 11:00-18:00» — для подстановки в текст автоответа.
    # Берём готовый хелпер страницы расписаний, чтобы формат совпадал с тем,
    # что сотрудники видят в Айсе, и группировка дней не разъезжалась.
    def summary
      return nil if schedule_source.nil?

      ApplicationController.helpers.format_working_hours_summary(schedule_source)
    end

    private

    def schedule_source
      return @schedule_source if defined?(@schedule_source)

      @schedule_source = @city && Department.real.in_city(@city).joins(:working_hours).first
    end

    def zone
      @city.time_zone.presence || DEFAULT_ZONE
    end

    # В DepartmentWorkingHours 0 — понедельник, а в Ruby Date#wday 0 — воскресенье.
    def row_for(date)
      schedule_source&.working_hours&.find_by(day_of_week: (date.wday + 6) % 7)
    end
  end
end
