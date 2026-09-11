# frozen_string_literal: true

module ClientChat
  # Открыт ли филиал прямо сейчас — по DepartmentWorkingHours, в часовом поясе
  # его города. Нужен автоответу: диалог может прийти ночью во Владивостоке,
  # когда сервер и залогиненный сотрудник живут в других поясах.
  class WorkingHours
    # Тот же запасной пояс, что в ScheduleEntry.
    DEFAULT_ZONE = 'Vladivostok'

    def self.open?(department, at: Time.current)
      new(department).open?(at)
    end

    def self.summary(department)
      new(department).summary
    end

    def initialize(department)
      @department = department
    end

    def open?(at = Time.current)
      # Филиал не определён — молчим: автоответ с чужими часами хуже молчания.
      return true if @department.nil?

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
      return nil if @department.nil?

      ApplicationController.helpers.format_working_hours_summary(@department)
    end

    private

    def zone
      @department.city&.time_zone.presence || DEFAULT_ZONE
    end

    # В DepartmentWorkingHours 0 — понедельник, а в Ruby Date#wday 0 — воскресенье.
    def row_for(date)
      @department.working_hours.find_by(day_of_week: (date.wday + 6) % 7)
    end
  end
end
