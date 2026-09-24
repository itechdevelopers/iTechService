require 'date'

module ActivityCounts
  class PeriodCounts
    def initialize(days:, today:, year: nil, branch_id: nil)
      raise ArgumentError, 'days must be an Array' unless days.is_a?(Array)
      raise ArgumentError, 'today must be a Date' unless today.is_a?(Date)

      @today = Date.new(today.year, today.month, today.day)
      @year = year.nil? ? @today.year : year
      unless @year.is_a?(Integer) && @year.between?(@today.year - 5, @today.year)
        raise ArgumentError, 'year must be between today.year - 5 and today.year'
      end
      unless branch_id.nil? || (branch_id.is_a?(String) && !blank?(branch_id))
        raise ArgumentError, 'branch_id must be a nonblank String'
      end

      @days = {}
      @branch_names = {}
      days.each { |day| load_day(day) }

      if !branch_id.nil? && !@branch_names.key?(branch_id)
        raise ArgumentError, 'unknown branch_id'
      end
      @branch_id = branch_id
    end

    def result
      current = measure(Date.new(@year, 1, 1), effective_cutoff(@year))
      previous_start, previous_end = annual_comparison_period
      previous = measure(previous_start, previous_end)

      {
        year: @year,
        through: effective_cutoff(@year)&.iso8601,
        quantity: current[:complete] ? current[:total] : nil,
        comparison: comparison(current, previous),
        months: month_results,
        history: history_results,
        branches: branch_results,
        branch_id: @branch_id,
        coverage_complete: current[:complete],
        missing_days: current[:missing_days]
      }
    end

    private

    def value(hash, key)
      string_key = key.to_s
      symbol_key = key.to_sym
      if hash.key?(string_key) && hash.key?(symbol_key)
        raise ArgumentError, "duplicate #{key} key"
      end
      return hash[string_key] if hash.key?(string_key)
      return hash[symbol_key] if hash.key?(symbol_key)

      raise ArgumentError, "missing #{key}"
    end

    def valid_quantity?(quantity)
      quantity.is_a?(Integer) && quantity >= 0
    end

    def blank?(value)
      value.nil? || (value.is_a?(String) && value.strip.empty?)
    end

    def load_day(day)
      raise ArgumentError, 'each day must be a Hash' unless day.is_a?(Hash)

      date_string = value(day, :date)
      unless date_string.is_a?(String) && date_string.match?(/\A\d{4}-\d{2}-\d{2}\z/)
        raise ArgumentError, 'date must be an ISO date string'
      end
      begin
        date = Date.iso8601(date_string)
      rescue Date::Error
        raise ArgumentError, 'invalid date'
      end
      raise ArgumentError, 'date must be canonical ISO format' unless date.iso8601 == date_string
      raise ArgumentError, 'duplicate date' if @days.key?(date)

      quantity = value(day, :quantity)
      raise ArgumentError, 'quantity must be a nonnegative Integer' unless valid_quantity?(quantity)

      branches = value(day, :branches)
      raise ArgumentError, 'branches must be an Array' unless branches.is_a?(Array)
      branch_quantities = {}
      branch_sum = 0

      branches.each do |branch|
        raise ArgumentError, 'each branch must be a Hash' unless branch.is_a?(Hash)
        id = value(branch, :id)
        name = value(branch, :name)
        branch_quantity = value(branch, :quantity)
        unless id.is_a?(String) && !blank?(id)
          raise ArgumentError, 'branch id must be a nonblank String'
        end
        raise ArgumentError, 'branch name must be a nonblank String' unless name.is_a?(String) && !blank?(name)
        raise ArgumentError, 'branch quantity must be a nonnegative Integer' unless valid_quantity?(branch_quantity)
        raise ArgumentError, 'repeated branch id for date' if branch_quantities.key?(id)

        if @branch_names.key?(id) && @branch_names[id] != name
          raise ArgumentError, 'branch name must be consistent across dates'
        end
        @branch_names[id] = name
        branch_quantities[id] = branch_quantity
        branch_sum += branch_quantity
      end

      raise ArgumentError, 'branch quantities must sum to day quantity' unless branch_sum == quantity

      @days[date] = { quantity: quantity, branches: branch_quantities }
    end

    def effective_cutoff(year)
      if year < @today.year
        Date.new(year, 12, 31)
      elsif year == @today.year && @today > Date.new(year, 1, 1)
        @today - 1
      end
    end

    def annual_comparison_period
      if @year < @today.year
        [Date.new(@year - 1, 1, 1), Date.new(@year - 1, 12, 31)]
      elsif (cutoff = effective_cutoff(@year))
        [Date.new(@year - 1, 1, 1), same_month_day(cutoff, @year - 1)]
      else
        [nil, nil]
      end
    end

    def same_month_day(date, year)
      day = [date.day, Date.new(year, date.month, -1).day].min
      Date.new(year, date.month, day)
    end

    def measure(first, last, branch_id: @branch_id)
      return { complete: false, missing_days: 0, total: nil } if first.nil? || last.nil? || last < first

      total = 0
      missing = 0
      date = first
      while date <= last
        supplied = @days[date]
        if supplied
          if branch_id.nil?
            total += supplied[:quantity]
          else
            # A supplied day with no entry for this branch represents zero.
            total += supplied[:branches].fetch(branch_id, 0)
          end
        else
          missing += 1
        end
        date += 1
      end

      complete = missing.zero?
      { complete: complete, missing_days: missing, total: complete ? total : nil }
    end

    def comparison(current, previous)
      if current[:complete] && previous[:complete]
        previous_quantity = previous[:total]
        change = if previous_quantity.zero?
                   nil
                 else
                   (current[:total] - previous_quantity) * 100.0 / previous_quantity
                 end
        { previous_quantity: previous_quantity, change_percent: change }
      else
        { previous_quantity: nil, change_percent: nil }
      end
    end

    def month_results
      (1..12).map do |month|
        first = Date.new(@year, month, 1)
        month_end = Date.new(@year, month, -1)
        cutoff = effective_cutoff(@year)
        last = cutoff && first <= cutoff ? [month_end, cutoff].min : nil
        current = measure(first, last)

        previous_first = Date.new(@year - 1, month, 1)
        previous_last = if last.nil?
                          nil
                        elsif last == month_end
                          Date.new(@year - 1, month, -1)
                        else
                          same_month_day(last, @year - 1)
                        end
        previous = measure(previous_first, previous_last)
        growth = comparison(current, previous)

        {
          month: month,
          quantity: current[:complete] ? current[:total] : nil,
          complete: current[:complete],
          period_closed: last == month_end,
          through: last&.iso8601,
          previous_quantity: growth[:previous_quantity],
          change_percent: growth[:change_percent]
        }
      end
    end

    def history_results
      # History is anchored to today, independently of the selected reporting year.
      (@today.year - 5..@today.year).map do |history_year|
        first = Date.new(history_year, 1, 1)
        last = effective_cutoff(history_year)
        current = measure(first, last)

        previous_first = Date.new(history_year - 1, 1, 1)
        previous_last = if history_year < @today.year
                          Date.new(history_year - 1, 12, 31)
                        elsif last
                          same_month_day(last, history_year - 1)
                        end
        previous = measure(previous_first, previous_last)
        growth = comparison(current, previous)

        {
          year: history_year,
          through: last&.iso8601,
          quantity: current[:complete] ? current[:total] : nil,
          complete: current[:complete],
          period_closed: history_year < @today.year,
          missing_days: current[:missing_days],
          previous_quantity: growth[:previous_quantity],
          change_percent: growth[:change_percent]
        }
      end
    end

    def branch_results
      ids = @branch_id.nil? ? @branch_names.keys : [@branch_id]
      rows = ids.map do |id|
        current = measure(Date.new(@year, 1, 1), effective_cutoff(@year), branch_id: id)
        previous_first, previous_last = annual_comparison_period
        previous = measure(previous_first, previous_last, branch_id: id)
        growth = comparison(current, previous)

        {
          id: id,
          name: @branch_names.fetch(id),
          quantity: current[:complete] ? current[:total] : nil,
          previous_quantity: growth[:previous_quantity],
          change_percent: growth[:change_percent]
        }
      end
      rows.sort_by do |row|
        [row[:quantity].nil? ? 1 : 0, row[:quantity].nil? ? 0 : -row[:quantity], row[:name].downcase, row[:id]]
      end
    end
  end

end
