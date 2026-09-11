module WeeklyMarkup
  class YearSummary
    def initialize(year: Date.current.year)
      @year = year
    end

    def call
      from = Date.new(@year, 1, 1)
      to = [Date.current - 1.day, Date.new(@year, 12, 31)].min
      data = DashboardData.new(from: from, to: to).call
      closed = data[:months].select { |month| month[:closed] }
      cost = closed.sum(BigDecimal('0')) { |month| month[:totals][:cost] }
      profit = closed.sum(BigDecimal('0')) { |month| month[:totals][:gross_profit] }
      {year: @year, markup: cost.zero? ? nil : profit / cost, closed_months: closed.size,
       through: closed.map { |month| month[:to] }.max,
       revenue: closed.sum(BigDecimal('0')) { |month| month[:totals][:revenue] },
       cost: cost, gross_profit: profit, drilldown_from: from, drilldown_to: to}
    end
  end
end
