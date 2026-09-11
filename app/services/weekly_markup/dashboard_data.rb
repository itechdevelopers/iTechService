require 'bigdecimal'

module WeeklyMarkup
  class DashboardData
    MONEY_KEYS = %w[revenue cost gross_profit cash noncash unallocated].freeze
    EXCLUDED_OPERATION_CODES = %w[00-00000377 00-00003075].freeze
    NONCASH_TAX_RATE = BigDecimal('0.10').freeze
    METHODOLOGY_VERSION = 'weekly-markup-dashboard-2.2.0'.freeze

    def initialize(from:, to:)
      @from, @to = from, to
    end

    def call
      imports = WeeklyMarkupImport.successful.overlapping(from, to).newest_first.to_a
      chosen = choose_imports(imports)
      source_days = (from..to).map { |day| build_day(day, chosen[day]) }
      products = build_products(chosen)
      excluded_products = products.select { |product| excluded_operation?(product) }
      days = apply_day_exclusions(source_days, excluded_products)
      included_products = products.reject { |product| excluded_operation?(product) }
      successful = chosen.values.compact.uniq
      latest_success = successful.max_by(&:calculated_at)
      latest_failure = WeeklyMarkupImport.failed.newest_first.first
      totals = sum_metrics(days)
      source_totals = sum_metrics(source_days)
      {
        period: {from: from, to: to}, days: days, branches: build_branches(chosen, excluded_products),
        totals: totals, weeks: build_weeks(days), months: build_months(days, chosen),
        source_totals: source_totals, excluded_operations: build_excluded_operations(excluded_products),
        categories: build_categories(included_products), products: included_products, category_a_products: category_a(included_products),
        noncash_tax: build_noncash_tax_breakdown(totals), methodology_version: METHODOLOGY_VERSION,
        gross_margin_breakdown: {source_revenue: source_totals[:revenue], excluded_operations: totals[:excluded_operations_amount],
                                 revenue: totals[:revenue], cost: totals[:cost],
                                 gross_profit_before_tax: totals[:gross_profit_before_tax], noncash_tax: totals[:noncash_tax],
                                 gross_profit: totals[:gross_profit], formula: 'Прибыль после налога / Выручка',
                                 result: totals[:gross_margin]},
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

    def build_branches(chosen, excluded_products)
      exclusions = excluded_products.each_with_object(Hash.new { |hash, key| hash[key] = empty_product_metrics }) do |product, index|
        product.fetch(:branches, []).each do |branch|
          branch[:days].each do |day|
            add_product_metrics(index[[branch[:warehouse_id], day[:date]]], day)
          end
        end
      end
      rows = {}
      chosen.each do |day, source|
        next unless source
        source.payload.fetch('branches', []).each do |branch|
          id = branch['warehouse_id'].to_s
          entry = (rows[id] ||= {warehouse_id: id, name: branch['name'], days: []})
          raw = branch.fetch('days', []).find { |item| item['date'] == day.iso8601 }
          if raw
            source = metrics(raw).merge(date: day, loaded: true)
            entry[:days] << adjust_profitability(source, exclusions[[id, day]])
          end
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
                                  category: product['category'].presence || 'Без группы', category_path: product['category_path'],
                                  excluded_from_profitability: product['excluded_from_profitability'] == true,
                                  days: [], branches: {}})
          entry[:days] << product_metrics(raw).merge(date: day)
          product.fetch('branches', []).each do |branch|
            branch_raw = branch.fetch('days', []).find { |item| item['date'] == day.iso8601 }
            next unless branch_raw
            branch_id = branch['warehouse_id'].to_s
            branch_entry = (entry[:branches][branch_id] ||= {warehouse_id: branch_id, days: []})
            branch_entry[:days] << product_metrics(branch_raw).merge(date: day)
          end
        end
      end
      rows.values.each do |entry|
        entry[:total] = sum_product_metrics(entry[:days])
        entry[:branches] = entry[:branches].values
        entry[:branches].each { |branch| branch[:total] = sum_product_metrics(branch[:days]) }
      end
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
      result = {operation_count: decimal(row['operation_count']), quantity: decimal(row['quantity']), revenue: decimal(row['revenue']), cost: decimal(row['cost']),
                gross_profit: decimal(row['gross_profit'])}
      add_ratios(result)
    end

    def empty_product_metrics
      {operation_count: BigDecimal('0'), quantity: BigDecimal('0'), revenue: BigDecimal('0'), cost: BigDecimal('0'), gross_profit: BigDecimal('0')}
    end

    def add_product_metrics(target, source)
      empty_product_metrics.keys.each { |key| target[key] += source[key] }
      target
    end

    def excluded_operation?(product)
      product[:excluded_from_profitability] || EXCLUDED_OPERATION_CODES.include?(product[:code])
    end

    def apply_day_exclusions(source_days, excluded_products)
      by_day = excluded_products.each_with_object(Hash.new { |hash, key| hash[key] = empty_product_metrics }) do |product, index|
        product[:days].each { |day| add_product_metrics(index[day[:date]], day) }
      end
      source_days.map { |day| adjust_profitability(day, by_day[day[:date]]) }
    end

    def adjust_profitability(source, excluded)
      result = source.dup
      result[:source_revenue] = source[:revenue]
      result[:excluded_operations_amount] = excluded[:revenue]
      result[:revenue] -= excluded[:revenue]
      result[:cost] -= excluded[:cost]
      result[:gross_profit_before_tax] = result[:revenue] - result[:cost]
      result[:gross_margin_before_tax] = percent(result[:gross_profit_before_tax], result[:revenue])
      result[:markup_before_tax] = percent(result[:gross_profit_before_tax], result[:cost])
      result[:noncash_tax] = source[:noncash] * NONCASH_TAX_RATE
      result[:gross_profit] = result[:gross_profit_before_tax] - result[:noncash_tax]
      add_ratios(result)
    end

    def build_noncash_tax_breakdown(totals)
      {base: totals[:noncash], rate: NONCASH_TAX_RATE, tax: totals[:noncash_tax],
       gross_profit_before_tax: totals[:gross_profit_before_tax], gross_profit_after_tax: totals[:gross_profit],
       gross_margin_before_tax: totals[:gross_margin_before_tax], gross_margin_after_tax: totals[:gross_margin],
       markup_before_tax: totals[:markup_before_tax], markup_after_tax: totals[:markup]}
    end

    def build_excluded_operations(products)
      rows = products.map do |product|
        {code: product[:code], name: product[:name], operation_count: product[:total][:operation_count],
         source_quantity: product[:total][:quantity], amount: product[:total][:revenue]}
      end.sort_by { |row| row[:code] }
      {rows: rows, operation_count: rows.sum(BigDecimal('0')) { |row| row[:operation_count] },
       amount: rows.sum(BigDecimal('0')) { |row| row[:amount] }}
    end

    def empty_metrics
      MONEY_KEYS.each_with_object({}) { |key, result| result[key.to_sym] = BigDecimal('0') }
    end

    def sum_metrics(rows)
      result = empty_metrics
      rows.select { |row| row[:loaded] != false }.each { |row| MONEY_KEYS.each { |key| result[key.to_sym] += row[key.to_sym] } }
      if rows.any? { |row| row.key?(:source_revenue) }
        result[:source_revenue] = rows.sum(BigDecimal('0')) { |row| row[:source_revenue] || row[:revenue] }
        result[:excluded_operations_amount] = rows.sum(BigDecimal('0')) { |row| row[:excluded_operations_amount] || BigDecimal('0') }
      end
      if rows.any? { |row| row.key?(:noncash_tax) }
        result[:gross_profit_before_tax] = rows.sum(BigDecimal('0')) { |row| row[:gross_profit_before_tax] || row[:gross_profit] }
        result[:noncash_tax] = rows.sum(BigDecimal('0')) { |row| row[:noncash_tax] || BigDecimal('0') }
        result[:gross_margin_before_tax] = percent(result[:gross_profit_before_tax], result[:revenue])
        result[:markup_before_tax] = percent(result[:gross_profit_before_tax], result[:cost])
      end
      add_ratios(result)
    end

    def sum_product_metrics(rows)
      result = {operation_count: BigDecimal('0'), quantity: BigDecimal('0'), revenue: BigDecimal('0'), cost: BigDecimal('0'), gross_profit: BigDecimal('0')}
      rows.each { |row| result.keys.each { |key| result[key] += row[key] } }
      add_ratios(result)
    end

    def add_ratios(result)
      result[:gross_margin] = percent(result[:gross_profit], result[:revenue])
      result[:markup] = percent(result[:gross_profit], result[:cost])
      result[:cash_share] = percent(result[:cash], result[:source_revenue] || result[:revenue]) if result.key?(:cash)
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
