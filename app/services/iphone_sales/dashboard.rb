require 'date'

module IphoneSales
  class Dashboard
    def initialize(year: nil, warehouse_id: nil, today: Time.current.in_time_zone('Asia/Vladivostok').to_date)
      @today = today
      @year = year || today.year
      @warehouse_id = warehouse_id.presence
    end

    def call
      records = IphoneSalesImport.successful.newest_first.select(:id, :period_from, :period_to, :calculated_at).to_a
      selected = {}
      records.each do |record|
        next if (record.period_from..record.period_to).all? { |date| selected.key?(date.iso8601) }
        payload = IphoneSalesImport.where(id: record.id).pluck(:payload).first
        payload.fetch('days').each { |day| selected[day['date']] ||= day }
      end
      catalog = selected.values.flat_map { |d| d['branches'] }.each_with_object({}) { |b, h| h[b['warehouse_id']] = b['name'] }
      raise ArgumentError, 'Неизвестный филиал' if @warehouse_id && !catalog.key?(@warehouse_id)
      days = selected.transform_values do |day|
        if @warehouse_id
          day['branches'].find { |b| b['warehouse_id'] == @warehouse_id }.try(:fetch, 'quantity') || 0
        else
          day['quantity']
        end
      end
      by_year = days.keys.map { |d| d[0, 4].to_i }.uniq.sort
      current = days.select { |d, _| d.start_with?("#{@year}-") && Date.iso8601(d) < @today }
      through = current.keys.max && Date.iso8601(current.keys.max)
      complete = through && covered?(days, Date.new(@year, 1, 1), through)
      forecast = through && complete ? predict(days, through) : nil
      months = (1..12).map do |month|
        from = Date.new(@year, month, 1)
        to = from.end_of_month
        entries = current.select { |d, _| d.start_with?(from.strftime('%Y-%m')) }
        {month: month, actual: entries.empty? ? nil : entries.values.sum,
         complete: covered?(days, from, to) && to < @today,
         forecast: forecast && forecast[:months][month - 1]}
      end
      branches = catalog.map do |id, name|
        values = (1..12).map do |month|
          month_days = selected.values.select { |d| d['date'].start_with?(format('%04d-%02d', @year, month)) && Date.iso8601(d['date']) < @today }
          month_days.empty? ? nil : month_days.sum { |d| d['branches'].find { |b| b['warehouse_id'] == id }.try(:fetch, 'quantity') || 0 }
        end
        {id: id, name: name, months: values, total: values.compact.sum}
      end.sort_by { |b| [-b[:total], b[:name]] }
      history = by_year.map do |year|
        values = (1..12).map do |month|
          from = Date.new(year, month, 1)
          part = days.select { |d, _| d.start_with?(from.strftime('%Y-%m')) && Date.iso8601(d) < @today }
          {quantity: part.empty? ? nil : part.values.sum, complete: covered?(days, from, from.end_of_month) && from.end_of_month < @today}
        end
        {year: year, months: values, total: values.map { |v| v[:quantity] }.compact.sum,
         complete: covered?(days, Date.new(year, 1, 1), Date.new(year, 12, 31)) && year < @today.year}
      end
      latest = records.first
      failure = IphoneSalesImport.where(status: 'failed').newest_first.first
      {year: @year, years: (by_year + [@today.year]).uniq.sort, quantity: current.empty? ? nil : current.values.sum,
       through: through, complete: complete, months: months, branches: branches, history: history,
       forecast: forecast, warehouse_id: @warehouse_id, warehouses: catalog,
       updated_at: latest&.calculated_at, stale: @year == @today.year && (!through || through < @today - 1),
       failed: failure && (!latest || failure.calculated_at > latest.calculated_at)}
    end

    private

    def covered?(days, from, to)
      (from..to).all? { |d| days.key?(d.iso8601) }
    end

    def median(values)
      sorted = values.sort
      n = sorted.size
      n.odd? ? sorted[n / 2] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2.0
    end

    def predict(days, through)
      return nil unless @year == @today.year && through < Date.new(@year, 12, 31)
      samples = ((@year - 6)...@year).select { |y| covered?(days, Date.new(y, 1, 1), Date.new(y, 12, 31)) }.last(3).filter_map do |y|
        annual = days.select { |d, _| d.start_with?("#{y}-") }.values.sum
        cutoff = Date.new(y, through.month, [through.day, Date.new(y, through.month, 1).end_of_month.day].min)
        elapsed = days.select { |d, _| d >= "#{y}-01-01" && d <= cutoff.iso8601 }.values.sum
        next unless annual.positive? && elapsed.positive? && elapsed < annual
        {year: y, total: annual, share: elapsed.to_f / annual,
         months: (1..12).map { |m| days.select { |d, _| d.start_with?(format('%04d-%02d', y, m)) }.values.sum.to_f / annual }}
      end
      return nil if samples.size < 2
      actual = days.select { |d, _| d >= "#{@year}-01-01" && d <= through.iso8601 }.values.sum
      return nil unless actual.positive?
      annual = (actual / median(samples.map { |s| s[:share] })).round
      weights = (1..12).map do |m|
        next 0.0 if m < through.month
        weight = median(samples.map { |s| s[:months][m - 1] })
        m == through.month ? weight * (through.end_of_month.day - through.day).to_f / through.end_of_month.day : weight
      end
      remaining = [annual - actual, 0].max
      allocations = weights.map { |w| weights.sum.positive? ? remaining * w / weights.sum : 0.0 }
      rounded = allocations.map(&:floor)
      order = allocations.each_index.sort_by { |n| -(allocations[n] - rounded[n]) }
      order.first(remaining - rounded.sum).each { |i| rounded[i] += 1 }
      projected = (1..12).map do |m|
        observed = days.select { |d, _| d.start_with?(format('%04d-%02d', @year, m)) && d <= through.iso8601 }.values.sum
        observed + rounded[m - 1]
      end
      {annual: projected.sum, low: (actual / samples.map { |s| s[:share] }.max).round,
       high: (actual / samples.map { |s| s[:share] }.min).round, months: projected,
       years: samples.map { |s| s[:year] }, peak_share: median(samples.map { |s| s[:months][8..11].sum })}
    end
  end
end
