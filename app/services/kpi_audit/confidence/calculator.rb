# frozen_string_literal: true

module KpiAudit
  module Confidence
    # Calculates visit reconstruction confidence with correlated-family caps.
    # rubocop:disable Metrics
    class Calculator
      DESCRIPTIONS = {
        shared_ticket: 'Один талон связывает несколько фактов.',
        singleton_ticket: 'Талон известен для одиночного факта.',
        waiting_client: 'Талон найден в электронной очереди.', historical_called: 'Найден исторический вызов талона.',
        service_job_relation: 'Факты связаны одной длинной приёмкой.', item: 'Совпало устройство.',
        serial: 'Совпал серийный номер.', imei: 'Совпал IMEI.', audit_metadata: 'Связь подтверждена audit metadata.',
        request_uuid: 'Совпал request UUID.', employee: 'Совпал сотрудник.', client: 'Совпал клиент.',
        time_proximity: 'Факты близки по времени.'
      }.freeze

      def initialize(events:, configuration: Configuration.load)
        @events = events
        @configuration = configuration
      end

      def call
        raw = evidence
        effective = apply_caps(raw)
        Assessment.new(score: effective.sum(&:effective_points), contributions: effective,
                       limitations: limitations(raw))
      end

      private

      def evidence
        list = []
        tickets = values(:ticket_id)
        if tickets.one?
          add(list, tickets.one? && @events.size > 1 ? :shared_ticket : :singleton_ticket, :queue_identity)
        end
        snapshots = @events.map(&:ticket_snapshot).compact
        add(list, :waiting_client, :queue_identity) if snapshots.any?
        add(list, :historical_called, :queue_identity) if snapshots.any? { |item| item[:called_id] }
        add(list, :service_job_relation, :device_identity) if shared?(:service_job_id)
        add(list, :item, :device_identity) if shared?(:device_id)
        add(list, :serial, :device_identity) if shared?(:serial)
        add(list, :imei, :device_identity) if shared?(:imei)
        add(list, :audit_metadata, :audit_identity) if @events.count(&:audit_metadata_confirmed) > 1
        add(list, :request_uuid, :audit_identity) if shared?(:audit_request_uuid)
        add(list, :employee, :context) if shared?(:employee_id)
        add(list, :client, :context) if shared?(:client_id)
        add(list, :time_proximity, :context) if close_in_time?
        list
      end

      def add(list, code, family)
        points = @configuration.fetch(:confidence, :weights, code)
        list << Contribution.new(code: code, description: DESCRIPTIONS.fetch(code), raw_points: points,
                                 effective_points: 0, family: family)
      end

      def apply_caps(contributions)
        used = Hash.new(0)
        total = 0
        contributions.map do |item|
          cap = @configuration.fetch(:confidence, :family_caps, item.family)
          effective = [item.raw_points, cap - used[item.family], 100 - total].min.clamp(0, item.raw_points)
          used[item.family] += effective
          total += effective
          Contribution.new(**item.to_h.merge(effective_points: effective))
        end
      end

      def limitations(contributions)
        result = ['Момент фактического ухода клиента не установлен.']
        codes = contributions.map(&:code)
        result << 'Историческое рабочее окно не найдено.' unless codes.include?(:historical_called)
        strong = codes.any? { |code| %i[shared_ticket service_job_relation item serial imei].include?(code) }
        result << 'Связь событий основана только на контекстных признаках.' unless strong
        result
      end

      def shared?(attribute)
        values(attribute).one? && @events.count { |event| event.public_send(attribute).present? } > 1
      end

      def values(attribute)
        @events.map { |event| event.public_send(attribute) }.compact
               .reject { |value| value.respond_to?(:empty?) && value.empty? }.uniq
      end

      def close_in_time?
        times = @events.map(&:occurred_at).compact
        times.size > 1 && times.max - times.min <= 30.minutes
      end
    end
    # rubocop:enable Metrics
  end
end
