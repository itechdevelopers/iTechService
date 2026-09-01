# frozen_string_literal: true

module KpiAudit
  # Builds economics only from unique Sale and Payment identifiers.
  # rubocop:disable Metrics, Style/MultilineBlockChain
  class EconomicOutcomeBuilder
    def initialize(events:)
      @events = events
    end

    def call
      sources = @events.flat_map { |event| Array(event.economic_sources) }
      sales = build_sales(sources)
      payments = build_payments(sources, sales)
      gross = payments.select { |line| confirmed_non_return?(line, sales) }.sum { |line| line.value.to_d }
      returns = payments.select { |line| confirmed_return?(line, sales) }.sum { |line| line.value.to_d }
      EconomicOutcome.new(
        sales: sales, payments: payments,
        posted_sales_count: sales.count(&:posted), unposted_sales_count: sales.count { |line| !line.posted },
        return_sales_count: sales.count(&:return_sale), gross_payments: gross,
        confirmed_returns: returns, net_confirmed_money: gross - returns,
        money_received: money_received(sales, gross - returns), confidence: confidence(sales),
        explanation: explanation(sales)
      )
    end

    private

    def build_sales(sources)
      sources.group_by { |source| source.dig(:sale, :id) }.reject { |id, _| id.nil? }.map do |_id, grouped|
        source = grouped.first.fetch(:sale)
        EconomicLine.new(type: :sale, id: source[:id], status: source[:status], posted: source[:posted],
                         return_sale: source[:return_sale], occurred_at: source[:occurred_at], url: source[:url],
                         related_kpi: grouped.flat_map { |item| item[:related_kpi] }.uniq.sort.freeze)
      end.sort_by(&:id).freeze
    end

    def build_payments(sources, sales)
      posted = sales.index_by(&:id)
      sources.flat_map do |source|
        Array(source[:payments]).map do |payment|
          payment.merge(related_kpi: (Array(payment[:related_kpi]) + Array(source[:related_kpi])).uniq)
        end
      end
             .group_by { |payment| payment[:id] }.map do |_id, grouped|
        payment = grouped.first
        sale = posted[payment[:sale_id]]
        EconomicLine.new(type: :payment, id: payment[:id], sale_id: payment[:sale_id],
                         posted: sale&.posted, return_sale: sale&.return_sale, value: payment[:value].to_d,
                         kind: payment[:kind], occurred_at: payment[:occurred_at],
                         related_kpi: grouped.flat_map { |item| Array(item[:related_kpi]) }.uniq.sort.freeze)
      end.sort_by(&:id).freeze
    end

    def confirmed_non_return?(payment, sales)
      sale = sales.find { |item| item.id == payment.sale_id }
      sale&.posted && !sale.return_sale
    end

    def confirmed_return?(payment, sales)
      sale = sales.find { |item| item.id == payment.sale_id }
      sale&.posted && sale&.return_sale
    end

    def money_received(sales, net)
      return nil if sales.empty? || sales.none?(&:posted)

      net.positive?
    end

    def confidence(sales)
      return :unknown if sales.empty?
      return :confirmed if sales.all?(&:posted)

      :partial
    end

    def explanation(sales)
      return 'Связанные продажи и оплаты не установлены.' if sales.empty?
      return 'Экономический итог рассчитан по уникальным проведённым продажам и платежам.' if sales.all?(&:posted)

      'Экономический результат подтверждён не полностью: присутствуют непроведённые продажи.'
    end
  end
  # rubocop:enable Metrics, Style/MultilineBlockChain
end
