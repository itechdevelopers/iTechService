require 'bigdecimal'

module WeeklyMarkup
  class DashboardData
    MONEY_KEYS = %w[revenue cost gross_profit cash noncash unallocated].freeze

    def initialize(from:, to:)
      @from, @to = from, to
    end

    def call
      imports = WeeklyMarkupImport.successful.overlapping(from, to).newest_first.to_a
      chosen = choose_imports(imports)
      days = (from..to).map { |day| build_day(day, chosen[day]) }
      products = build_products(chosen)
      successful = chosen.values.compact.uniq
      latest_success = successful.max_by(&:calculated_at)
      latest_failure = WeeklyMarkupImport.failed.newest_first.first
      totals = sum_metrics(days)
      {
        period: {from: from, to: to}, days: days, branches: build_branches(chosen),
        totals: totals, weeks: build_weeks(days), months: build_months(days, chosen),
        categories: build_categories(products), products: products, category_a_products: category_a(products),
        gross_margin_breakdown: {revenue: totals[:revenue], cost: totals[:cost], gross_profit: totals[:gross_profit],
                                 formula: 'Валовая прибыль / Выручка', result: totals[:gross_margin]},
        missing_dates: days.select { |row| !row[:loaded] }.map { |row| row[:date] },
        incomplete_dates: days.select { |row| row[:incomplete] }.map { |row| row[:date] },
        preliminary_cost_dates: days.select { |row| row[:loaded] && !row[:cost_complete] }.map { |row| row[:date] },
        zero_cost_revenue_dates: days.select { |row| row[:loaded] && !row[:revenue].zero? && row[:cost].zero? }.map { |row| row[:date] },
        discrepancies: collect_discrepancies(chosen), versions: successful.map { |item| version_hash(item) },
        current_version: latest_success && version_hash(latest_success),
        as_of_local: latest_success&.payload&.dig('freshness', 'as_of_local'),
        update_failed: latest_failure && (!latest_success || latest_failure.created_at > latest_success.created_at),
        latest_failure_at: latest_failure&.created_at,
      }
    end

    private

    attr_reader :from, :to

    def choose_imports(imports)
      (from..to).each_with_object({}) { |day, result| result[day] = imports.find { |item| item.period_from <= day && item.period_to >= day } }
    end

    def build_day(day, source)
      return empty_metrics.merge(date: day, loaded: false, incomplete: false, cost_complete: false) unless source
      raw = source.payload.dig('totals', 'days').find { |row| row['date'] == day.iso8601 }
      return empty_metrics.merge(date: day, loaded: false, incomplete: false, cost_complete: false) unless raw
      metrics(raw).merge(date: day, loaded: true,
                         incomplete: Array(source.payload.dig('freshness', 'incomplete_dates')).include?(day.iso8601),
                         cost_complete: source.payload.dig('checks', 'cost_data_complete') == true,
                         import_id: source.id)
    end

    def build_branches(chosen)
      rows = {}
      chosen.each do |day, source|
        next unless source
        source.payload.fetch('branches', []).each do |branch|
          id = branch['warehouse_id'].to_s
          entry = (rows[id] ||= {warehouse_id: id, name: branch['name'], days: []})
          raw = branch.fetch('days', []).find { |item| item['date'] == day.iso8601 }
          entry[:days] << metrics(raw).merge(date: day, loaded: true) if raw
        end
      end
      rows.values.each { |entry| entry[:total] = sum_metrics(entry[:days]) }
      rows.values.sort_by { |entry| [entry[:name] == 'Для сотрудников' ? 1 : 0, entry[:name].to_s] }
    end

    def build_products(chosen)
      rows = {}
      chosen.each do |day, source|
        next unless source
        source.payload.dig('sales_analytics', 'products').to_a.each do |product|
          raw = product.fetch('days', []).find { |item| item['date'] == day.iso8601 }
          next unless raw
          id = product['item_id'].to_s
          entry = (rows[id] ||= {item_id: id, code: product['code'], name: product['name'], item_type: product['item_type'],
                                  category: product['category'].presence || 'Без группы', category_path: product['category_path'], days: []})
          entry[:days] << product_metrics(raw).merge(date: day)
        end
      end
      rows.values.each { |entry| entry[:total] = sum_product_metrics(entry[:days]) }
      rows.values.sort_by { |entry| [-entry[:total][:gross_profit], entry[:name].to_s] }
    end

    def build_categories(products)
      categories = products.group_by { |row| row[:category] }.map do |name, rows|
        {name: name, product_count: rows.size, total: sum_product_metrics(rows.map { |row| row[:total] })}
      end
      revenue = categories.sum(BigDecimal('0')) { |row| row[:total][:revenue] }
      categories.each { |row| row[:total][:revenue_share] = percent(row[:total][:revenue], revenue) }
      categories.sort_by { |row| [-row[:total][:gross_profit], row[:name].to_s] }
    end

    def category_a(products)
      positive = products.select { |row| row[:total][:gross_profit] > 0 }.sort_by { |row| -row[:total][:gross_profit] }
      total_profit = positive.sum(BigDecimal('0')) { |row| row[:total][:gross_profit] }
      cumulative = BigDecimal('0')
      positive.each_with_object([]) do |row, result|
        break result if total_profit.zero? || cumulative / total_profit >= BigDecimal('0.8')
        cumulative += row[:total][:gross_profit]
        result << row.merge(gross_profit_share: row[:total][:gross_profit] / total_profit,
                            cumulative_gross_profit_share: cumulative / total_profit)
      end
    end

    def metrics(row)
      result = MONEY_KEYS.each_with_object({}) { |key, values| values[key.to_sym] = decimal(row[key]) }
      add_ratios(result)
    end

    def product_metrics(row)
      result = {quantity: decimal(row['quantity']), revenue: decimal(row['revenue']), cost: decimal(row['cost']),
                gross_profit: decimal(row['gross_profit'])}
      add_ratios(result)
    end

    def empty_metrics
      MONEY_KEYS.each_with_object({}) { |key, result| result[key.to_sym] = BigDecimal('0') }
    end

    def sum_metrics(rows)
      result = empty_metrics
      rows.select { |row| row[:loaded] != false }.each { |row| MONEY_KEYS.each { |key| result[key.to_sym] += row[key.to_sym] } }
      add_ratios(result)
    end

    def sum_product_metrics(rows)
      result = {quantity: BigDecimal('0'), revenue: BigDecimal('0'), cost: BigDecimal('0'), gross_profit: BigDecimal('0')}
      rows.each { |row| result.keys.each { |key| result[key] += row[key] } }
      add_ratios(result)
    end

    def add_ratios(result)
      result[:gross_margin] = percent(result[:gross_profit], result[:revenue])
      result[:markup] = percent(result[:gross_profit], result[:cost])
      result[:cash_share] = percent(result[:cash], result[:revenue]) if result.key?(:cash)
      result
    end

    def decimal(value)
      text = value.to_s
      BigDecimal(text.empty? ? '0' : text)
    end

    def percent(numerator, denominator)
      denominator.zero? ? nil : numerator / denominator
    end

    def build_weeks(days)
      days.group_by { |row| row[:date].beginning_of_week(:monday) }.map do |week_start, rows|
        expected = (week_start..week_start + 6.days).to_a
        loaded = rows.select { |row| row[:loaded] }.map { |row| row[:date] }
        {from: week_start, to: week_start + 6.days, totals: sum_metrics(rows),
         incomplete: loaded.sort != expected || rows.any? { |row| row[:incomplete] }}
      end
    end

    def build_months(days, chosen)
      days.group_by { |row| row[:date].beginning_of_month }.map do |month_start, rows|
        month_end = month_start.end_of_month
        complete_dates = (month_start..month_end).all? { |day| chosen[day] && rows.any? { |row| row[:date] == day && row[:loaded] } }
        closed = complete_dates && month_end < Date.current && rows.none? { |row| row[:incomplete] || !row[:cost_complete] }
        {from: month_start, to: month_end, totals: sum_metrics(rows), closed: closed, status: closed ? 'Закрыт' : 'Предварительный'}
      end
    end

    def collect_discrepancies(chosen)
      chosen.values.compact.uniq.flat_map do |source|
        source.payload.fetch('discrepancies', []).select do |item|
          day = Date.iso8601(item['date'])
          day.between?(from, to) && chosen[day] == source
        end
      end
    end

    def version_hash(item)
      {id: item.id, delivery_id: item.delivery_id, period_from: item.period_from, period_to: item.period_to,
       calculated_at: item.calculated_at, methodology_version: item.methodology_version}
    end
  end
end
