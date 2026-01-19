# frozen_string_literal: true

module SchedulesHelper
  DAY_NAMES_SHORT = %w[Пн Вт Ср Чт Пт Сб Вс].freeze

  def format_working_hours_summary(department)
    hours = department.working_hours.ordered.to_a
    return t('schedules.index.working_hours_not_set') if hours.empty?

    groups = group_consecutive_days(hours)
    groups.map { |group| format_group(group) }.join(', ')
  end

  private

  def group_consecutive_days(hours)
    groups = []
    current_group = []

    hours.each do |wh|
      if current_group.empty? || same_schedule?(current_group.last, wh)
        current_group << wh
      else
        groups << current_group
        current_group = [wh]
      end
    end
    groups << current_group unless current_group.empty?
    groups
  end

  def same_schedule?(wh1, wh2)
    wh1.is_closed == wh2.is_closed &&
      wh1.opens_at == wh2.opens_at &&
      wh1.closes_at == wh2.closes_at
  end

  def format_group(group)
    first_day = group.first
    last_day = group.last

    day_range = if group.size == 1
                  DAY_NAMES_SHORT[first_day.day_of_week]
                else
                  "#{DAY_NAMES_SHORT[first_day.day_of_week]}-#{DAY_NAMES_SHORT[last_day.day_of_week]}"
                end

    if first_day.is_closed?
      "#{day_range} #{t('schedules.index.closed')}"
    else
      "#{day_range} #{first_day.opens_at&.strftime('%H:%M')}-#{first_day.closes_at&.strftime('%H:%M')}"
    end
  end
end
