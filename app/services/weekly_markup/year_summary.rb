module WeeklyMarkup
  class YearSummary
    def initialize(year: Date.current.year)
      @year = year
    end

    def call
      from = Date.new(@year, 1, 1)
      to = [Date.current - 1.day, Date.new(@year, 12, 31)].min
      data = DashboardData.new(from: from, to: to).call
      included = data[:months].select { |month| month[:eligible_for_yearly_markup] }
      cost = included.sum(BigDecimal('0')) { |month| month[:totals][:cost] }
      profit = included.sum(BigDecimal('0')) { |month| month[:totals][:gross_profit] }
      previous_month_date = Date.current.prev_month.beginning_of_month
      previous_month = data[:months].find do |month|
        month[:from] == previous_month_date && month[:eligible_for_yearly_markup]
      end
      {year: @year, markup: cost.zero? ? nil : profit / cost, closed_months: included.size,
       through: included.map { |month| month[:to] }.max,
       previous_month: previous_month && {from: previous_month[:from], to: previous_month[:to],
                                           status: previous_month[:status], markup: previous_month[:totals][:markup]},
       revenue: included.sum(BigDecimal('0')) { |month| month[:totals][:revenue] },
       cost: cost, gross_profit: profit, drilldown_from: from, drilldown_to: to}
    end
  end
end
