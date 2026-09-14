require 'date'
require 'time'

module IphoneSales
  class Import
    class InvalidReport < StandardError; end

    def self.call(delivery_id:, report:)
      new(delivery_id, report).call
    end

    def initialize(id, report)
      @id, @report = id.to_s, report
    end

    def call
      invalid! unless @id.match?(/\A[0-9a-f]{64}\z/) && @report.is_a?(Hash)
      existing = IphoneSalesImport.find_by(delivery_id: @id)
      return [existing, :duplicate] if existing
      invalid! unless @report['schema_version'] == 'ice-iphone-sales-1.0'
      from, to = %w[from to].map { |key| Date.iso8601(@report.fetch('period').fetch(key)) }
      invalid! if to < from || (to - from).to_i > 365
      stamp = Time.iso8601(@report.fetch('calculated_at'))
      invalid! if stamp > Time.current + 5.minutes
      method = @report.fetch('methodology_version')
      invalid! unless method == 'iphone-sales-1.0'
      invalid! unless %w[successful failed].include?(@report['status'])
      status = @report['status']
      validate_days!(from, to) if status == 'successful'
      record = IphoneSalesImport.create!(delivery_id: @id, period_from: from, period_to: to,
        calculated_at: stamp, methodology_version: method, status: status, payload: @report)
      [record, :created]
    rescue ActiveRecord::RecordNotUnique
      [IphoneSalesImport.find_by!(delivery_id: @id), :duplicate]
    rescue KeyError, ArgumentError, TypeError
      invalid!
    end

    private

    def validate_days!(from, to)
      invalid! unless @report.dig('checks', 'passed') == true &&
        @report.dig('checks', 'all_pages_received') == true && @report.dig('checks', 'duplicates') == 0 &&
        @report.dig('source', 'read_only') == true && @report.dig('source', 'http_methods') == ['GET']
      days = @report.fetch('days')
      invalid! unless days.is_a?(Array) && days.map { |d| d.fetch('date') }.sort == (from..to).map(&:iso8601)
      names = {}
      days.each do |day|
        quantity!(day.fetch('quantity'))
        branches = day.fetch('branches')
        invalid! unless branches.is_a?(Array) && branches.size <= 100
        ids = branches.map { |b| b.fetch('warehouse_id') }
        invalid! unless ids.uniq.size == ids.size
        branches.each do |branch|
          id, name = branch.values_at('warehouse_id', 'name')
          invalid! unless id.is_a?(String) && id.match?(/\A[0-9a-f-]{36}\z/) && name.is_a?(String) && name.size.between?(1, 150)
          invalid! if names[id] && names[id] != name
          names[id] = name
          quantity!(branch.fetch('quantity'))
        end
        invalid! unless branches.sum { |b| b['quantity'] } == day['quantity']
      end
      quantity!(@report.fetch('quantity'))
      invalid! unless days.sum { |d| d['quantity'] } == @report['quantity']
    end

    def quantity!(value)
      invalid! unless value.is_a?(Integer) && value.abs <= 10_000_000
    end

    def invalid!
      raise InvalidReport, 'Некорректный отчёт iPhone'
    end
  end
end
