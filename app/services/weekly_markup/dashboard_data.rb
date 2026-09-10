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
      branches = build_branches(chosen)
      successful = chosen.values.compact.uniq
      latest_success = successful.max_by(&:calculated_at)
      latest_failure = WeeklyMarkupImport.failed.newest_first.first
      {
        period: {from: from, to: to}, days: days, branches: branches,
        totals: sum_metrics(days), weeks: build_weeks(days),
        missing_dates: days.select { |row| !row[:loaded] }.map { |row| row[:date] },
        incomplete_dates: days.select { |row| row[:incomplete] }.map { |row| row[:date] },
        zero_cost_revenue_dates: days.select { |row| row[:loaded] && !row[:revenue].zero? && row[:cost].zero? }.map { |row| row[:date] },
        discrepancies: collect_discrepancies(chosen),
        versions: successful.map { |item| version_hash(item) },
        current_version: latest_success && version_hash(latest_success),
        as_of_local: latest_success&.payload&.dig('freshness', 'as_of_local'),
        update_failed: latest_failure && (!latest_success || latest_failure.created_at > latest_success.created_at),
        latest_failure_at: latest_failure&.created_at,
      }
    end

    private

    attr_reader :from, :to

    def choose_imports(imports)
      (from..to).each_with_object({}) do |day, result|
        result[day] = imports.find { |item| item.period_from <= day && item.period_to >= day }
      end
    end

    def build_day(day, source)
      return empty_metrics.merge(date: day, loaded: false, incomplete: false) unless source
      raw = source.payload.dig('totals', 'days').find { |row| row['date'] == day.iso8601 }
      return empty_metrics.merge(date: day, loaded: false, incomplete: false) unless raw
      metrics(raw).merge(date: day, loaded: true,
                         incomplete: Array(source.payload.dig('freshness', 'incomplete_dates')).include?(day.iso8601),
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
          next unless raw
          entry[:days] << metrics(raw).merge(date: day, loaded: true)
        end
      end
      rows.values.each { |entry| entry[:total] = sum_metrics(entry[:days]) }
      rows.values.sort_by { |entry| [entry[:name] == 'Для сотрудников' ? 1 : 0, entry[:name].to_s] }
    end

    def metrics(row)
      result = MONEY_KEYS.each_with_object({}) { |key, values| values[key.to_sym] = BigDecimal(row.fetch(key)) }
      result[:gross_margin] = percent(result[:gross_profit], result[:revenue])
      result[:markup] = percent(result[:gross_profit], result[:cost])
      result
    end

    def empty_metrics
      MONEY_KEYS.each_with_object({}) { |key, result| result[key.to_sym] = BigDecimal('0') }
    end

    def sum_metrics(rows)
      result = empty_metrics
      rows.select { |row| row[:loaded] }.each do |row|
        MONEY_KEYS.each { |key| result[key.to_sym] += row[key.to_sym] }
      end
      result[:gross_margin] = percent(result[:gross_profit], result[:revenue])
      result[:markup] = percent(result[:gross_profit], result[:cost])
      result
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
