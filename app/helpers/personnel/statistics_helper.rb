module Personnel
  module StatisticsHelper
    MONTHS_BACK = 12

    def month_options
      first = Date.current.beginning_of_month
      (0..MONTHS_BACK).map do |offset|
        date = (first << offset)
        [l(date, format: '%B %Y'), date.to_s]
      end
    end
  end
end
