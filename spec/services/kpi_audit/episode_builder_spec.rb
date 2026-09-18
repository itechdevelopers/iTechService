# frozen_string_literal: true

require_relative '../../support/kpi_audit_unit_helper'
require_relative '../../../app/services/kpi_audit/episode'
require_relative '../../../app/services/kpi_audit/episode_builder'

# rubocop:disable Metrics/BlockLength, Lint/ConstantDefinitionInBlock
RSpec.describe KpiAudit::EpisodeBuilder do
  Contribution = Struct.new(:code, :effective_points, :description, keyword_init: true) do
    def to_h
      { code: code, effective_points: effective_points, description: description }
    end
  end
  Assessment = Struct.new(:score, :level, keyword_init: true)
  Snapshot = Struct.new(:value) do
    def to_h
      value
    end
  end
  CaseRecord = Struct.new(:summary, :employee, :visit_profile, :risk_score, :risk_level,
                          :risk_breakdown, :confidence, :timeline, :economic_outcome,
                          :video_summary, :related_records, :limitations, keyword_init: true)

  def investigation(ticket_id:, records:, profile:, risk:, signals:)
    CaseRecord.new(
      summary: 'Основание для проверки', employee: { id: 423, full_name: 'Редько Кирилл', login: 'redko' },
      visit_profile: profile.merge(ticket_ids: [ticket_id]), risk_score: risk, risk_level: :high,
      risk_breakdown: signals.map do |code|
        Contribution.new(code: code, effective_points: 10, description: code.to_s)
      end,
      confidence: Assessment.new(score: 85, level: :high), timeline: Snapshot.new([]),
      economic_outcome: Snapshot.new(payments: [], sales: [], net_confirmed_money: 0),
      video_summary: Snapshot.new(ticket_id: ticket_id), related_records: records, limitations: []
    )
  end

  it 'shows one episode with merged signals for multiple detector cases of one ticket' do
    profile = { kpi_count: 25, free_services_count: 22, long_receptions_count: 2, mac_works_count: 1 }
    records = [{ type: :free_job, source_id: 44_055, occurred_at: Time.zone.now }]
    investigations = [
      investigation(ticket_id: 114_974, records: records, profile: profile, risk: 73,
                    signals: %i[burst short_intervals]),
      investigation(ticket_id: 114_974, records: records, profile: profile, risk: 22,
                    signals: %i[repeated_device])
    ]

    episodes = described_class.call(investigations)

    expect(episodes.size).to eq(1)
    expect(episodes.first.signals.map { |item| item[:code] }).to contain_exactly(
      :burst, :short_intervals, :repeated_device
    )
  end

  it 'hides a normal linked long reception and Mac workflow' do
    profile = { kpi_count: 2, free_services_count: 0, long_receptions_count: 1, mac_works_count: 1 }
    records = [
      { type: :service_job, source_id: 160_021, service_job_id: 160_021, occurred_at: Time.zone.now },
      { type: :mac, source_id: 198_968, service_job_id: 160_021, occurred_at: Time.zone.now }
    ]
    cases = [investigation(ticket_id: 114_952, records: records, profile: profile, risk: 25,
                           signals: %i[multiple_kpi confirmed_ticket repeated_device])]

    expect(described_class.call(cases)).to be_empty
  end
end
# rubocop:enable Metrics/BlockLength, Lint/ConstantDefinitionInBlock
