module WeeklyMarkupDashboardsHelper
  def markup_money(value)
    number_to_currency(value, unit: '₽', separator: ',', delimiter: ' ', format: '%n %u')
  end

  def markup_percent(value)
    value.nil? ? '—' : number_to_percentage(value * 100, precision: 2, separator: ',')
  end

  def markup_quantity(value)
    number_with_delimiter(value.to_s('F').sub(/\.0+\z/, ''), delimiter: ' ', separator: ',')
  end
end
