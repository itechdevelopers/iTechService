require 'bigdecimal'
require 'date'
require 'time'

module WeeklyMarkup
  class Import
    MONEY_KEYS = %w[revenue cost gross_profit cash noncash unallocated].freeze

    class InvalidReport < StandardError; end

    def self.call(delivery_id:, report:)
      new(delivery_id, report).call
    end

    def initialize(delivery_id, report)
      @delivery_id = delivery_id.to_s
      @report = report
    end

    def call
      existing = WeeklyMarkupImport.find_by(delivery_id: delivery_id)
      return [existing, :duplicate] if existing&.status == 'successful'

      attributes = validate!
      if existing
        existing.update!(attributes.merge(status: 'successful', payload: report, error_message: nil))
        [existing, :recovered]
      else
        record = WeeklyMarkupImport.create!(attributes.merge(status: 'successful', payload: report))
        [record, :created]
      end
    rescue ActiveRecord::RecordNotUnique
      [WeeklyMarkupImport.find_by!(delivery_id: delivery_id), :duplicate]
    end

    private

    attr_reader :delivery_id, :report

    def validate!
      invalid!('delivery_id') unless delivery_id.match?(/\A[0-9a-f]{64}\z/)
      invalid!('report') unless report.is_a?(Hash)
      invalid!('schema_version') unless report['schema_version'] == 'ice-weekly-markup-1.0'
      invalid!('checks') unless report.dig('checks', 'passed') == true
      invalid!('read_only') unless report.dig('source', 'read_only') == true && report.dig('source', 'http_methods') == ['GET']

      from = Date.iso8601(report.dig('period', 'from').to_s)
      to = Date.iso8601(report.dig('period', 'to').to_s)
      invalid!('period') if to < from || (to - from).to_i > 31
      calculated_at = Time.iso8601(report['calculated_at'].to_s)
      methodology = report['methodology_version'].to_s
      invalid!('methodology_version') if methodology.empty?

      totals = report.fetch('totals')
      days = totals.fetch('days')
      expected_dates = (from..to).map(&:iso8601)
      invalid!('days') unless days.is_a?(Array) && days.map { |row| row['date'] }.sort == expected_dates
      invalid!('duplicate days') unless days.map { |row| row['date'] }.uniq.size == days.size
      MONEY_KEYS.each do |key|
        assert_money!(totals[key], "totals.#{key}")
        sum = days.sum(BigDecimal('0')) { |row| decimal(row[key], "days.#{key}") }
        invalid!("days total #{key}") unless cents(sum) == cents(decimal(totals[key], "totals.#{key}"))
      end
      assert_equations!(totals, 'totals')
      days.each { |row| assert_equations!(row, "day #{row['date']}") }

      branches = report.fetch('branches')
      invalid!('branches') unless branches.is_a?(Array)
      invalid!('duplicate branches') unless branches.map { |row| row['warehouse_id'] }.uniq.size == branches.size
      MONEY_KEYS.each do |key|
        sum = branches.sum(BigDecimal('0')) { |branch| decimal(branch.dig('total', key), "branch #{key}") }
        invalid!("branches total #{key}") unless cents(sum) == cents(decimal(totals[key], "totals.#{key}"))
      end

      validate_sales_analytics!(report['sales_analytics'], from, to) if report['sales_analytics']

      {delivery_id: delivery_id, period_from: from, period_to: to, calculated_at: calculated_at,
       methodology_version: methodology}
    rescue ArgumentError, KeyError, TypeError => e
      raise InvalidReport, e.message
    end

    def assert_equations!(row, label)
      revenue = decimal(row['revenue'], "#{label}.revenue")
      cost = decimal(row['cost'], "#{label}.cost")
      profit = decimal(row['gross_profit'], "#{label}.gross_profit")
      cash = decimal(row['cash'], "#{label}.cash")
      noncash = decimal(row['noncash'], "#{label}.noncash")
      unallocated = decimal(row['unallocated'], "#{label}.unallocated")
      invalid!("#{label} gross profit") unless cents(revenue - cost) == cents(profit)
      invalid!("#{label} payments") unless cents(cash + noncash + unallocated) == cents(revenue)
    end

    def validate_sales_analytics!(analytics, from, to)
      products = analytics.fetch('products')
      invalid!('sales analytics products') unless products.is_a?(Array)
      invalid!('duplicate products') unless products.map { |row| row['item_id'] }.uniq.size == products.size
      products.each do |product|
        days = product.fetch('days')
        invalid!('duplicate product days') unless days.map { |row| row['date'] }.uniq.size == days.size
        days.each do |row|
          day = Date.iso8601(row['date'].to_s)
          invalid!('product day period') unless day.between?(from, to)
          assert_product_equations!(row, "product #{product['item_id']} day #{row['date']}")
        end
        assert_product_equations!(product.fetch('total'), "product #{product['item_id']} total")
        %w[revenue cost gross_profit].each do |key|
          sum = days.sum(BigDecimal('0')) { |row| decimal(row[key], "product day #{key}") }
          invalid!("product total #{key}") unless cents(sum) == cents(decimal(product.dig('total', key), "product total #{key}"))
        end
        validate_product_branches!(product, from, to) if product['branches']
      end
    end

    def validate_product_branches!(product, from, to)
      branches = product['branches']
      invalid!('product branches') unless branches.is_a?(Array)
      invalid!('duplicate product branches') unless branches.map { |row| row['warehouse_id'] }.uniq.size == branches.size
      branches.each do |branch|
        days = branch.fetch('days')
        invalid!('duplicate product branch days') unless days.map { |row| row['date'] }.uniq.size == days.size
        days.each do |row|
          day = Date.iso8601(row['date'].to_s)
          invalid!('product branch day period') unless day.between?(from, to)
          assert_product_equations!(row, "product #{product['item_id']} branch #{branch['warehouse_id']} day #{row['date']}")
        end
        assert_product_equations!(branch.fetch('total'), "product #{product['item_id']} branch #{branch['warehouse_id']} total")
        %w[operation_count quantity revenue cost gross_profit].each do |key|
          sum = days.sum(BigDecimal('0')) { |row| decimal(row[key], "product branch day #{key}") }
          invalid!("product branch days total #{key}") unless cents(sum) == cents(decimal(branch.dig('total', key), "product branch total #{key}"))
        end
      end
      %w[operation_count quantity revenue cost gross_profit].each do |key|
        sum = branches.sum(BigDecimal('0')) { |branch| decimal(branch.dig('total', key), "product branch total #{key}") }
        invalid!("product branches total #{key}") unless cents(sum) == cents(decimal(product.dig('total', key), "product total #{key}"))
      end
    end

    def assert_product_equations!(row, label)
      revenue = decimal(row['revenue'], "#{label}.revenue")
      cost = decimal(row['cost'], "#{label}.cost")
      profit = decimal(row['gross_profit'], "#{label}.gross_profit")
      decimal(row['operation_count'], "#{label}.operation_count")
      decimal(row['quantity'], "#{label}.quantity")
      invalid!("#{label} gross profit") unless cents(revenue - cost) == cents(profit)
    end

    def assert_money!(value, label)
      decimal(value, label)
    end

    def decimal(value, label)
      invalid!(label) unless value.is_a?(String) && value.match?(/\A-?\d+(?:\.\d+)?\z/)
      BigDecimal(value)
    end

    def cents(value)
      value.round(2)
    end

    def invalid!(field)
      raise InvalidReport, "Некорректное поле: #{field}"
    end
  end
end
