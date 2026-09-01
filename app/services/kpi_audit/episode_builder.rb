# frozen_string_literal: true

require 'digest'

module KpiAudit
  # Combines detector-specific cases into one user-facing episode per visit.
  # rubocop:disable Metrics
  class EpisodeBuilder
    NORMAL_LINKED_MAC_SIGNALS = %w[multiple_kpi confirmed_ticket repeated_device].freeze

    def self.call(investigations)
      new(investigations).call
    end

    def initialize(investigations)
      @investigations = investigations
    end

    def call
      @investigations.group_by { |investigation| group_key(investigation) }
                     .reject { |_key, cases| normal_linked_mac?(cases) }
                     .map { |key, cases| build_episode(key, cases) }
                     .sort_by { |episode| [-episode.risk_score, -episode.confidence[:score], episode.id] }
    end

    private

    def group_key(investigation)
      ticket_ids = investigation.visit_profile[:ticket_ids]
      return "employee:#{investigation.employee[:id]}:ticket:#{ticket_ids.first}" if ticket_ids.one?

      records = investigation.related_records.map { |item| "#{item[:type]}:#{item[:source_id]}" }.sort
      "employee:#{investigation.employee[:id]}:records:#{records.join(',')}"
    end

    def normal_linked_mac?(cases)
      profile = reference_case(cases).visit_profile
      counts = profile.values_at(:free_services_count, :long_receptions_count, :mac_works_count).map(&:to_i)
      return false unless counts == [0, 1, 1]
      return false unless linked_service_job_and_mac?(merge_records(cases))

      signal_codes(cases).all? { |code| NORMAL_LINKED_MAC_SIGNALS.include?(code) }
    end

    def linked_service_job_and_mac?(records)
      jobs = records.select { |item| item[:type].to_sym == :service_job }
      macs = records.select { |item| item[:type].to_sym == :mac }
      jobs.one? && macs.one? && macs.first[:service_job_id] == jobs.first[:source_id]
    end

    def build_episode(key, cases)
      reference = reference_case(cases)
      risk_case = cases.max_by(&:risk_score)
      confidence_case = cases.max_by { |item| item.confidence.score }
      Episode.new(
        id: Digest::SHA256.hexdigest(key)[0, 24], summary: reference.summary,
        employee: reference.employee, visit_profile: reference.visit_profile,
        signals: merged_signals(cases), risk_score: risk_case.risk_score,
        risk_level: risk_case.risk_level,
        confidence: { score: confidence_case.confidence.score, level: confidence_case.confidence.level },
        timeline: merge_timeline(cases), economic_outcome: richest_economics(cases),
        video_summary: reference.video_summary.to_h, related_records: merge_records(cases),
        limitations: cases.flat_map(&:limitations).uniq
      )
    end

    def reference_case(cases)
      cases.max_by { |item| [item.visit_profile[:kpi_count].to_i, item.risk_score] }
    end

    def signal_codes(cases)
      cases.flat_map(&:risk_breakdown).map { |item| item.code.to_s }.uniq
    end

    def merged_signals(cases)
      grouped = cases.flat_map(&:risk_breakdown).group_by(&:code)
      signals = grouped.map do |_code, contributions|
        contributions.max_by(&:effective_points).to_h
      end
      signals.sort_by { |item| [-item[:effective_points], item[:code].to_s] }
    end

    def merge_timeline(cases)
      cases.flat_map { |item| item.timeline.to_h }
           .uniq { |entry| [entry[:type], entry[:source_type], entry[:source_id], entry[:occurred_at]] }
           .sort_by { |entry| [entry[:occurred_at] || Time.at(0), entry[:source_type].to_s, entry[:source_id].to_i] }
    end

    def merge_records(cases)
      cases.flat_map(&:related_records)
           .uniq { |item| [item[:type], item[:source_id]] }
           .sort_by { |item| [item[:occurred_at] || Time.at(0), item[:type].to_s, item[:source_id].to_i] }
    end

    def richest_economics(cases)
      cases.map { |item| item.economic_outcome.to_h }
           .max_by { |item| [item[:payments].size, item[:sales].size, item[:net_confirmed_money].to_d] }
    end
  end
  # rubocop:enable Metrics
end
