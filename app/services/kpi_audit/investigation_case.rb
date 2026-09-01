# frozen_string_literal: true

module KpiAudit
  # Immutable JSON-ready boundary for an internal manual-review candidate.
  # rubocop:disable Metrics, Style/MultilineBlockChain
  class InvestigationCase
    ATTRIBUTES = %i[id summary employee visit_profile timeline confidence risk_score risk_level
                    risk_breakdown economic_outcome video_summary related_records limitations
                    rules_version configuration_digest generated_at].freeze
    attr_reader(*ATTRIBUTES)

    def initialize(**attributes)
      ATTRIBUTES.each { |name| instance_variable_set("@#{name}", attributes.fetch(name)) }
      freeze
    end

    def self.build(id:, employee:, anomaly:, video_summary:, configuration:, generated_at:)
      economics = EconomicOutcomeBuilder.new(events: anomaly.events).call
      confidence = Confidence::Calculator.new(events: anomaly.events, configuration: configuration).call
      risk = Scorecard.new(configuration: configuration).assess(anomaly.reasons)
      timeline = TimelineBuilder.new(events: anomaly.events, economic_outcome: economics).call
      new(
        id: id, summary: anomaly.reasons.first&.text || 'Аномалия KPI',
        employee: employee_snapshot(employee), visit_profile: visit_snapshot(anomaly, timeline), timeline: timeline,
        confidence: confidence, risk_score: risk.score, risk_level: risk.level,
        risk_breakdown: risk.contributions, economic_outcome: economics, video_summary: video_summary,
        related_records: record_snapshots(anomaly.events),
        limitations: limitations(confidence, economics, video_summary, timeline),
        rules_version: configuration.fetch(:rules_version),
        configuration_digest: configuration_digest(configuration), generated_at: generated_at
      )
    end

    def to_h(diagnostics: false)
      {
        id: id, summary: summary, employee: employee, visit_profile: visit_profile,
        timeline: timeline.to_h, confidence: confidence.to_h, risk_score: risk_score,
        risk_level: risk_level, risk_breakdown: risk_breakdown.map(&:to_h),
        economic_outcome: economic_outcome.to_h, video_summary: video_summary.to_h(diagnostics: diagnostics),
        related_records: related_records, limitations: limitations, rules_version: rules_version,
        configuration_digest: configuration_digest, generated_at: generated_at
      }
    end

    def self.id_for(employee_id, anomaly)
      record_keys = anomaly.events.map { |event| "#{event.kind}:#{event.id}" }.sort
      ticket_keys = anomaly.events.map(&:ticket_id).compact.uniq.sort.map { |id| "ticket:#{id}" }
      Digest::SHA256.hexdigest((["employee:#{employee_id}", "type:#{anomaly.type}"] +
                                record_keys + ticket_keys).join('|'))[0, 24]
    end

    class << self
      private

      def employee_snapshot(employee)
        { id: employee.id, full_name: employee.full_name.to_s, login: employee.login.to_s }.freeze
      end

      def visit_snapshot(anomaly, timeline)
        events = anomaly.events
        { started_at: anomaly.started_at, ended_at: anomaly.ended_at, facts_count: timeline.entries.size,
          kpi_count: events.size, free_services_count: events.count { |event| event.kind == :free_job },
          long_receptions_count: events.count { |event| event.kind == :service_job },
          mac_works_count: events.count { |event| event.kind == :mac },
          ticket_ids: events.map(&:ticket_id).compact.uniq.sort,
          reconstruction: primitive(anomaly.evidence) }.freeze
      end

      def record_snapshots(events)
        events.map do |event|
          { type: event.kind, source_type: event.record.class.name, source_id: event.id,
            occurred_at: event.occurred_at, ticket_id: event.ticket_id,
            service_job_id: event.service_job_id, device_id: event.device_id,
            serial: event.serial, imei: event.imei, url: event.url }.freeze
        end.sort_by { |item| [item[:occurred_at], item[:type].to_s, item[:source_id]] }.freeze
      end

      def limitations(confidence, economics, video, timeline)
        values = confidence.limitations.dup
        values << economics.explanation unless economics.confidence == :confirmed
        values << (video.explanation || 'Видео-контекст определить невозможно.') unless video.available?
        timeline_types = timeline.entries.map(&:type)
        values << 'Время выдачи талона не установлено.' unless timeline_types.include?(:ticket_issued)
        values << 'Время завершения талона не установлено.' unless timeline_types.include?(:ticket_completed)
        values.uniq.freeze
      end

      def configuration_digest(configuration)
        Digest::SHA256.hexdigest(JSON.generate(deep_sort(configuration.data)))
      end

      def deep_sort(value)
        case value
        when Hash then value.keys.sort_by(&:to_s).to_h { |key| [key, deep_sort(value[key])] }
        when Array then value.map { |item| deep_sort(item) }
        else value
        end
      end

      def primitive(value)
        case value
        when Hash then value.transform_values { |item| primitive(item) }
        when Array then value.map { |item| primitive(item) }
        when Time, Date, DateTime, String, Symbol, Numeric, NilClass, TrueClass, FalseClass then value
        else value.respond_to?(:to_h) ? primitive(value.to_h) : value.to_s
        end
      end
    end
  end
  # rubocop:enable Metrics, Style/MultilineBlockChain
end
