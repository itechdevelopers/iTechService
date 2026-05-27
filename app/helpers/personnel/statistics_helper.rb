module Personnel
  module StatisticsHelper
    MONTHS_BACK = 12

    def month_options
      first = Date.current.beginning_of_month
      (0..MONTHS_BACK).map do |offset|
        date = (first << offset)
        [nominative_month_year(date), date.to_s]
      end
    end

    def nominative_month_year(date)
      "#{I18n.t('date.month_names_single')[date.month]} #{date.year}"
    end
  end
end
