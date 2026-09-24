require 'date'
require 'time'

module ActivityCounts
  class Import
    class InvalidReport < StandardError; end
    METRICS = %w[receipts issued_repairs].freeze

    def self.call(delivery_id:, report:, allowed_metric: 'receipts')
      new(delivery_id, report, allowed_metric).call
    end

    def initialize(id, report, allowed_metric)
      @id, @report, @metric = id.to_s, report, allowed_metric
    end

    def call
      validate!
      result = nil
      ActivityCountImport.transaction do
        # Serialize publication per metric, including concurrent first imports.
        lock = @metric == 'receipts' ? 734_241 : 734_242
        ActivityCountImport.connection.execute("SELECT pg_advisory_xact_lock(#{lock})")
        existing = ActivityCountImport.find_by(metric: @metric, delivery_id: @id)
        return [existing, :duplicate] if existing
        record = ActivityCountImport.create!(metric: @metric, delivery_id: @id,
          period_from: @from, period_to: @to, calculated_at: @stamp, payload: @report)
        @report.fetch('days').each do |day|
          stored = ActivityCountDay.find_or_initialize_by(metric: @metric, date: day.fetch('date'))
          if stored.persisted?
            source = stored.activity_count_import
            # Equal source timestamps cannot overwrite an already published snapshot.
            next if source.calculated_at >= @stamp
          end
          stored.update!(quantity: day.fetch('quantity'), branches: day.fetch('branches'), activity_count_import: record)
        end
        result = [record, :created]
      end
      result
    rescue KeyError, ArgumentError, TypeError
      invalid!
    end

    private

    def validate!
      invalid! unless METRICS.include?(@metric) && @id.match?(/\A[0-9a-f]{64}\z/) && @report.is_a?(Hash)
      invalid! unless @report['schema_version'] == 'activity-counts-1.0' && @report['metric'] == @metric
      invalid! unless @report['methodology_version'] == (@metric == 'receipts' ? 'posted-receipts-1.0' : 'first-archive-issue-1.0')
      invalid! unless @report['period'].is_a?(Hash)
      @from, @to = %w[from to].map { |k| Date.iso8601(@report.fetch('period').fetch(k)) }
      today = Time.current.in_time_zone('Asia/Vladivostok').to_date
      invalid! if @to < @from || (@to - @from).to_i > 366 || @to >= today
      @stamp = Time.iso8601(@report.fetch('calculated_at'))
      invalid! if @stamp > Time.current + 5.minutes
      invalid! unless @report.dig('checks', 'all_pages_received') == true && @report.dig('checks', 'duplicates') == 0
      if @metric == 'receipts'
        invalid! unless @report.dig('source', 'read_only') == true && @report.dig('source', 'http_methods') == ['GET']
      end
      days = @report.fetch('days')
      invalid! unless days.is_a?(Array) && days.all? { |day| day.is_a?(Hash) }
      invalid! unless days.map { |d| d.fetch('date') }.sort == (@from..@to).map(&:iso8601)
      names = {}
      days.each do |day|
        count!(day.fetch('quantity'))
        branches = day.fetch('branches')
        invalid! unless branches.is_a?(Array) && branches.size <= 200 && branches.all? { |branch| branch.is_a?(Hash) }
        ids = branches.map { |b| b.fetch('id') }
        invalid! unless ids.uniq.size == ids.size
        branches.each do |b|
          id, name = b.values_at('id', 'name')
          invalid! unless id.is_a?(String) && id.match?(/\A[a-zA-Z0-9_-]{1,64}\z/) && name.is_a?(String) && name.size.between?(1, 150)
          invalid! if names[id] && names[id] != name
          names[id] = name
          count!(b.fetch('quantity'))
        end
        invalid! unless branches.sum { |b| b['quantity'] } == day['quantity']
      end
      count!(@report.fetch('quantity'))
      invalid! unless days.sum { |d| d['quantity'] } == @report['quantity']
    end

    def count!(value)
      invalid! unless value.is_a?(Integer) && value.between?(0, 10_000_000)
    end

    def invalid!
      raise InvalidReport, 'Некорректная загрузка показателей'
    end
  end
end
