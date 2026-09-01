# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength

require_relative '../../support/kpi_audit_unit_helper'
require_relative '../../support/hikvision_metadata_spec_helper'
require 'active_record'
require_relative '../../../app/services/kpi_audit/timeline'
require_relative '../../../app/services/kpi_audit/timeline_builder'
require_relative '../../../app/services/kpi_audit/confidence'
require_relative '../../../app/services/kpi_audit/confidence/calculator'
require_relative '../../../app/services/kpi_audit/economic_outcome'
require_relative '../../../app/services/kpi_audit/economic_outcome_builder'
require_relative '../../../app/services/kpi_audit/investigation_case'
require_relative '../../../app/services/kpi_audit/read_only_runner'
require_relative '../../../app/services/kpi_audit/video_summary'
require_relative '../../../app/services/kpi_audit/video_link'
require_relative '../../../app/services/kpi_audit/video_summary_builder'
require_relative '../../../app/services/kpi_audit/analyzer'

RSpec.describe 'KPI Audit PHASE A backend' do
  let(:zone) { Time.find_zone!('Vladivostok') }
  let(:record_class) { Struct.new(:id) }

  def event(id:, kind: :free_job, at: nil, **attributes)
    KpiAudit::Event.new({ kind: kind, record: record_class.new(id), employee_id: 7, client_id: 8,
                          occurred_at: at || zone.parse('2026-07-29 06:00:00'),
                          operation_key: "#{kind}:work", video_diagnostic: {}, economic_sources: [] }.merge(attributes))
  end

  describe KpiAudit::Analyzer do
    it 'keeps the public API working without KPI routes or an internal transaction' do
      department = double(id: 2, city_id: 1, name: 'Отдел')
      user = double(id: 7, full_name: 'Иванов Иван', username: 'ivanov')
      events = Array.new(5) do |index|
        event(id: index + 1, ticket_id: 114_974,
              at: zone.parse('2026-07-29 06:00:00') + index.seconds)
      end
      collector = Class.new do
        define_method(:initialize) { |**_options| nil }
        define_method(:call) { events }
      end
      stub_const('Department', double('Department class', find: department))
      stub_const('User', double('User class', where: [user]))
      timesheet_scope = double
      allow(timesheet_scope).to receive(:where).and_return(timesheet_scope)
      allow(timesheet_scope).to receive(:group).and_return(timesheet_scope)
      allow(timesheet_scope).to receive(:count).and_return({})
      stub_const('TimesheetDay', double('TimesheetDay class', work: timesheet_scope))
      expect(ActiveRecord::Base).not_to receive(:transaction)

      analysis = described_class.for_month(department_id: 2, year: 2026, month: 7, mode: :strict,
                                           configuration: KPI_AUDIT_TEST_CONFIG, collector_class: collector)

      expect(analysis.investigations).not_to be_empty
      expect(analysis.date_from).to eq(Date.new(2026, 7, 1))
      expect(analysis.date_to).to eq(Date.new(2026, 7, 31))
      expect(analysis.investigations.map { |item| item.video_summary.primary_link }.compact).to be_empty
    end
  end

  describe KpiAudit::ReadOnlyRunner do
    it 'sets read-only once at a top-level boundary, rolls back and returns the result' do
      connection = double(adapter_name: 'PostgreSQL', open_transactions: 0)
      owner = double
      expect(connection).to receive(:execute).with('SET TRANSACTION READ ONLY').once
      allow(owner).to receive(:transaction) do |&block|
        block.call
      rescue ActiveRecord::Rollback
        nil
      end

      result = described_class.call(connection: connection, transaction_owner: owner) { :analysis }
      expect(result).to eq(:analysis)
    end

    it 'rejects nested use before issuing SET TRANSACTION' do
      connection = double(adapter_name: 'PostgreSQL', open_transactions: 1)

      expect(connection).not_to receive(:execute)
      expect do
        described_class.call(connection: connection, transaction_owner: double) { :analysis }
      end.to raise_error(KpiAudit::ReadOnlyRunner::NestedTransactionError)
    end
  end

  describe KpiAudit::Confidence::Calculator do
    it 'does not assign high confidence to client-only evidence' do
      events = [event(id: 1), event(id: 2, at: zone.parse('2026-07-30 06:00:00'))]
      assessment = described_class.new(events: events, configuration: KPI_AUDIT_TEST_CONFIG).call

      expect(assessment.level).to eq(:low)
      expect(assessment.contributions.map(&:code)).to contain_exactly(:employee, :client)
    end

    it 'does not assign artificial 100 to a singleton ticket event' do
      assessment = described_class.new(events: [event(id: 1, ticket_id: 114_974)],
                                       configuration: KPI_AUDIT_TEST_CONFIG).call

      expect(assessment.score).to be < 70
    end

    it 'assigns high, fully explained confidence when independent facts share strong evidence' do
      ticket = { id: 114_974, called_id: 1 }
      events = [event(id: 1, ticket_id: 114_974, ticket_snapshot: ticket, service_job_id: 5,
                      device_id: 6, serial: 'S', imei: 'I', audit_metadata_confirmed: true),
                event(id: 2, ticket_id: 114_974, ticket_snapshot: ticket, service_job_id: 5,
                      device_id: 6, serial: 'S', imei: 'I', audit_metadata_confirmed: true,
                      at: zone.parse('2026-07-29 06:01:00'))]
      assessment = described_class.new(events: events, configuration: KPI_AUDIT_TEST_CONFIG).call

      expect(assessment.level).to eq(:high)
      expect(assessment.score).to eq(assessment.contributions.sum(&:effective_points))
      device = assessment.contributions.select { |item| item.family == :device_identity }
      expect(device.sum(&:effective_points)).to eq(30)
      expect(device.sum(&:raw_points)).to be > 30
    end
  end

  describe KpiAudit::EconomicOutcomeBuilder do
    def source(sale_id:, payment_id:, value: 5000, return_sale: false, related: 'service_job:1')
      { sale: { id: sale_id, status: 1, posted: true, return_sale: return_sale,
                occurred_at: zone.parse('2026-07-29 06:02:00'), url: nil },
        payments: [{ id: payment_id, sale_id: sale_id, value: value, kind: 'card',
                     occurred_at: zone.parse('2026-07-29 06:03:00'), related_kpi: [related] }],
        related_kpi: [related] }
    end

    it 'counts a ServiceJob and Mac payment from the same Sale once' do
      shared = source(sale_id: 123, payment_id: 456)
      events = [event(id: 1, kind: :service_job, economic_sources: [shared]),
                event(id: 2, kind: :mac, economic_sources: [shared.merge(related_kpi: ['mac:2'])])]
      outcome = described_class.new(events: events).call

      expect(outcome.payments.size).to eq(1)
      expect(outcome.gross_payments).to eq(5000.to_d)
    end

    it 'counts different payments with the same amount separately' do
      events = [event(id: 1, economic_sources: [source(sale_id: 1, payment_id: 10)]),
                event(id: 2, economic_sources: [source(sale_id: 2, payment_id: 11)])]

      expect(described_class.new(events: events).call.gross_payments).to eq(10_000.to_d)
    end

    it 'does not subtract an unlinked client return' do
      events = [event(id: 1, economic_sources: [source(sale_id: 1, payment_id: 10)])]
      outcome = described_class.new(events: events).call

      expect(outcome.confirmed_returns).to eq(0.to_d)
      expect(outcome.net_confirmed_money).to eq(5000.to_d)
    end
  end

  describe KpiAudit::TimelineBuilder do
    it 'is chronological and contains 22 FreeJob entries in one timeline' do
      ticket = { id: 114_974, issued_at: zone.parse('2026-07-29 05:59:00'), called_id: 9,
                 called_at: zone.parse('2026-07-29 06:00:00'), window_number: 8,
                 served_at: zone.parse('2026-07-29 06:08:00') }
      events = Array.new(22) do |index|
        event(id: 44_055 + index, at: zone.parse('2026-07-29 06:00:29') + index.seconds,
              ticket_id: 114_974, ticket_snapshot: ticket)
      end
      economics = KpiAudit::EconomicOutcomeBuilder.new(events: events).call
      timeline = described_class.new(events: events, economic_outcome: economics).call
      visits = KpiAudit::VisitReconstructor.new(events: events, configuration: KPI_AUDIT_TEST_CONFIG).call

      expect(visits.size).to eq(1)
      expect(timeline.entries.count { |item| item.type == :free_service_created }).to eq(22)
      expect(timeline.entries.map(&:occurred_at)).to eq(timeline.entries.map(&:occurred_at).sort)
      completed = timeline.entries.find { |item| item.type == :ticket_completed }
      expect(completed.title).to eq('Талон завершён')
      expect(timeline.entries.map(&:title)).not_to include('Клиент ушёл')
    end
  end

  describe KpiAudit::Scorecard do
    it 'exposes combination bonuses and preserves the score invariant' do
      reasons = [KpiAudit::Reason.new(code: :burst, text: 'Серия', points: 20, family: :burst),
                 KpiAudit::Reason.new(code: :repeated_device, text: 'Устройство', points: 22,
                                      family: :repetition)]
      assessment = described_class.new(configuration: KPI_AUDIT_TEST_CONFIG).assess(reasons)

      expect(assessment.contributions.map(&:code)).to include(:burst_repeated_entity)
      expect(assessment.score).to eq(assessment.contributions.sum(&:effective_points))
    end

    it 'keeps USER_MISMATCH at zero risk' do
      reason = KpiAudit::Reason.new(code: :user_mismatch, text: 'Диагностика', points: 0, family: :diagnostics)
      expect(described_class.new(configuration: KPI_AUDIT_TEST_CONFIG).assess([reason]).score).to eq(0)
    end

    it 'classifies an over-cap aggregate without raising' do
      expect(described_class.new(configuration: KPI_AUDIT_TEST_CONFIG).level(101)).to eq(:critical)
    end
  end

  describe KpiAudit::Detector do
    it 'never interprets a city Plan as an individual employee target' do
      events = Array.new(6) do |index|
        event(id: index + 1, at: zone.parse('2026-07-29 06:00:00') + index.minutes,
              ticket_id: 1)
      end
      visits = KpiAudit::VisitReconstructor.new(events: events, configuration: KPI_AUDIT_TEST_CONFIG).call
      anomalies = described_class.new(events: events, visits: visits, date_from: Date.new(2026, 7, 1),
                                      date_to: Date.new(2026, 7, 31), mode: :strict,
                                      plans: { 'free' => 6 }, work_days: {},
                                      configuration: KPI_AUDIT_TEST_CONFIG).call

      expect(anomalies.values.flatten.flat_map(&:reasons).map(&:code)).not_to include(:plan_proximity)
    end
  end

  describe KpiAudit::InvestigationCase do
    let(:employee) do
      KpiAudit::EmployeeResult.new(id: 7, full_name: 'Иванов Иван', login: 'secret-login',
                                   risk_score: 0, risk_level: :low, statistics: {}, anomalies: [])
    end
    let(:video) do
      KpiAudit::VideoSummary.new(available: false, playback_available: false, status: 'NO_CALLED',
                                 explanation: 'Историческое рабочее окно не установлено.',
                                 confidence_score: 0, confidence_reasons: [], alternative_links: [], diagnostics: {})
    end

    def anomaly_for(events)
      reason = KpiAudit::Reason.new(code: :burst, text: '22 Бесплатных сервиса', points: 35, family: :burst)
      KpiAudit::Anomaly.new(type: :multiple_kpi_visit, score: 35, reasons: [reason], events: events,
                            started_at: events.map(&:occurred_at).min, ended_at: events.map(&:occurred_at).max,
                            evidence: { visit_confidence: :strong }, monetary_result: {})
    end

    it 'has a stable non-PII ID and a recursively serializable boundary' do
      events = [event(id: 2, ticket_id: 10), event(id: 1, ticket_id: 10)]
      first = anomaly_for(events)
      second = anomaly_for(events.reverse)

      expect(described_class.id_for(7, first)).to eq(described_class.id_for(7, second))
      id = described_class.id_for(7, first)
      expect(id).not_to include('Иванов', 'secret-login')
      investigation = described_class.build(
        id: id, employee: employee, anomaly: first, video_summary: video,
        configuration: KPI_AUDIT_TEST_CONFIG, generated_at: zone.parse('2026-07-29 07:00:00')
      )
      expect { JSON.generate(investigation.to_h) }.not_to raise_error
      expect(investigation.limitations).to include('Момент фактического ухода клиента не установлен.')
      expect(investigation.to_h.inspect).not_to match(/#<ServiceJob|#<Service::FreeJob|ActiveRecord/)
    end
  end
end

# rubocop:enable Metrics/BlockLength
