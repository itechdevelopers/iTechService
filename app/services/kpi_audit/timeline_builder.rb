# frozen_string_literal: true

module KpiAudit
  # Builds a deterministic timeline without inventing missing events.
  class TimelineBuilder
    KPI_TITLES = {
      service_job: ['long_reception_created', 'Длинная приёмка'],
      free_job: ['free_service_created', 'Бесплатный сервис'],
      mac: ['mac_work_completed', 'Работа с Mac']
    }.freeze

    def initialize(events:, economic_outcome:)
      @events = events
      @economic_outcome = economic_outcome
    end

    def call
      Timeline.new(queue_entries + kpi_entries + economic_entries)
    end

    private

    def queue_entries
      tickets = @events.map(&:ticket_snapshot).compact.uniq { |item| item[:id] }
      tickets.flat_map do |ticket|
        [entry(type: :ticket_issued, occurred_at: ticket[:issued_at], title: 'Выдан талон электронной очереди',
               source_type: 'WaitingClient', source_id: ticket[:id]),
         entry(type: :ticket_called, occurred_at: ticket[:called_at], title: 'Клиент вызван к рабочему окну',
               source_type: 'ElqueueTicketMovement::Called', source_id: ticket[:called_id],
               description: "Рабочее окно №#{ticket[:window_number]}"),
         entry(type: :ticket_completed, occurred_at: ticket[:served_at], title: 'Талон завершён',
               source_type: 'WaitingClient', source_id: ticket[:id])].compact
      end
    end

    def kpi_entries
      @events.map do |event|
        type, title = KPI_TITLES.fetch(event.kind)
        entry(type: type.to_sym, occurred_at: event.occurred_at, title: title,
              source_type: event.record.class.name, source_id: event.id, url: event.url)
      end
    end

    def economic_entries
      sales = @economic_outcome.sales.select(&:posted).map do |sale|
        entry(type: :sale_posted, occurred_at: sale.occurred_at, title: 'Продажа проведена',
              source_type: 'Sale', source_id: sale.id, description: sale.return_sale ? 'Возврат' : nil,
              url: sale.url)
      end
      payments = @economic_outcome.payments.map do |payment|
        entry(type: :payment_received, occurred_at: payment.occurred_at, title: 'Поступила оплата',
              source_type: 'Payment', source_id: payment.id, description: "#{payment.value.to_d} ₽")
      end
      sales + payments
    end

    # rubocop:disable Metrics/ParameterLists
    def entry(type:, occurred_at:, title:, source_type:, source_id:, description: nil, url: nil)
      return nil unless occurred_at

      TimelineEntry.new(type: type, occurred_at: occurred_at, time_status: :exact, title: title,
                        description: description, source_type: source_type, source_id: source_id,
                        url: url, confidence: 100)
    end
    # rubocop:enable Metrics/ParameterLists
  end
end
