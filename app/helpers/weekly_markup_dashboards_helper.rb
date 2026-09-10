module WeeklyMarkupDashboardsHelper
  def markup_money(value)
    number_to_currency(value, unit: '₽', separator: ',', delimiter: ' ', format: '%n %u')
  end

  def markup_percent(value)
    value.nil? ? '—' : number_to_percentage(value * 100, precision: 2, separator: ',')
  end
end
