module ActivityCounts
  class Dashboard
    LABELS = {'receipts' => 'Продажи', 'issued_repairs' => 'Ремонты'}.freeze

    def initialize(metric:, year: nil, branch_id: nil, today: Time.current.in_time_zone('Asia/Vladivostok').to_date)
      raise ArgumentError unless LABELS.key?(metric)
      @metric, @today, @year, @branch_id = metric, today, year || today.year, branch_id.presence
      raise ArgumentError unless @year.is_a?(Integer) && @year.between?(today.year - 5, today.year)
    end

    def call
      version = ActivityCountImport.where(metric: @metric).maximum(:id) || 0
      Rails.cache.fetch(['activity-counts-v1', @metric, version, @today.iso8601, @year, @branch_id], expires_in: 5.minutes) do
        rows = ActivityCountDay.where(metric: @metric, date: Date.new(@today.year - 6, 1, 1)..(@today - 1))
          .includes(:activity_count_import).order(:date).to_a
        # Catalog labels may change between immutable historical snapshots.
        names = {}
        rows.each { |row| row.branches.each { |branch| names[branch['id']] = branch['name'] } }
        days = rows.map do |row|
          {date: row.date.iso8601, quantity: row.quantity,
           branches: row.branches.map { |b| b.merge('name' => names.fetch(b['id'])) }}
        end
        last_current = rows.select { |row| row.date.year == @today.year }.last
        effective_today = last_current ? [@today, last_current.date + 1].min : @today
        data = PeriodCounts.new(days: days, today: effective_today, year: @year, branch_id: @branch_id).result
        data.merge(metric: @metric, title: LABELS.fetch(@metric),
          years: ((@today.year - 5)..@today.year).to_a, branch_names: names,
          updated_at: last_current&.activity_count_import&.calculated_at,
          stale: !last_current || last_current.date < @today - 1)
      end
    end
  end
end
