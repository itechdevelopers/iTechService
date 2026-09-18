# frozen_string_literal: true

# rubocop:disable Metrics, Layout/LineLength

require_relative '../../support/kpi_audit_unit_helper'

RSpec.describe KpiAudit::Detector do
  def event(id:, at:, kind: :free_job, ticket: nil, client: nil, serial: nil, money: 0, operation: 'same',
            diagnostic: nil)
    KpiAudit::Event.new(kind: kind, record: Struct.new(:id).new(id), employee_id: 7, client_id: client,
                        occurred_at: Time.zone.parse(at), ticket_id: ticket, serial: serial,
                        operation_key: operation, monetary_amount: money, video_diagnostic: diagnostic || { status: 'UNRESOLVED' })
  end

  def detect(events, mode: :normal)
    visits = KpiAudit::VisitReconstructor.new(events: events, configuration: KPI_AUDIT_TEST_CONFIG).call
    described_class.new(events: events, visits: visits, date_from: Date.new(2026, 7, 1),
                        date_to: Date.new(2026, 7, 31), mode: mode, plans: {}, work_days: {},
                        configuration: KPI_AUDIT_TEST_CONFIG).call.fetch(7)
  end

  it 'finds ten FreeJobs on one ticket in one minute as a burst' do
    events = 10.times.map { |i| event(id: i, at: "2026-07-10 10:00:#{format('%02d', i * 5)}", ticket: 42) }
    anomaly = detect(events).find { |item| item.reasons.any? { |reason| reason.code == :burst } }
    expect(anomaly).to be_present
    expect(anomaly.evidence[:intervals_seconds][:median]).to eq(5.0)
  end

  it 'reports ServiceJob plus FreeJob in normal mode as a moderate signal' do
    events = [event(id: 1, kind: :service_job, at: '2026-07-10 10:00', ticket: 42),
              event(id: 2, at: '2026-07-10 10:01', ticket: 42)]
    anomaly = detect(events).first
    expect(anomaly.score).to be_between(25, 49)
  end

  it 'always reports the same confirmed multi-KPI visit in strict mode' do
    events = [event(id: 1, kind: :service_job, at: '2026-07-10 10:00', ticket: 42),
              event(id: 2, at: '2026-07-10 10:01', ticket: 42)]
    expect(detect(events, mode: :strict)).not_to be_empty
  end

  it 'treats repeated serial as stronger than repeated client' do
    events = [event(id: 1, at: '2026-07-01 10:00', ticket: 1, serial: 'XYZ'),
              event(id: 2, at: '2026-07-10 10:00', ticket: 2, serial: 'XYZ')]
    anomaly = detect(events, mode: :strict).find { |item| item.type == :repeated_device }
    expect(anomaly.reasons.first.points).to eq(22)
  end

  it 'finds an end-of-period spike' do
    events = (1..20).map { |day| event(id: day, at: "2026-07-#{format('%02d', day)} 10:00") }
    events += 8.times.map { |i| event(id: 100 + i, at: "2026-07-31 10:#{format('%02d', i)}") }
    expect(detect(events).map(&:type)).to include(:end_of_period)
  end

  it 'makes end-period growth without monetary result a high combined risk' do
    events = (1..20).map do |day|
      event(id: day, kind: :service_job, at: "2026-07-#{format('%02d', day)} 10:00", money: 100)
    end
    events += 8.times.map { |i| event(id: 100 + i, kind: :service_job, at: "2026-07-31 10:#{format('%02d', i)}") }
    anomaly = detect(events).find { |item| item.type == :end_of_period }
    expect(anomaly.score).to be >= 50
  end

  it 'does not assign high risk to stable ordinary work' do
    events = (1..25).map { |day| event(id: day, at: "2026-07-#{format('%02d', day)} 10:00", ticket: day) }
    expect(detect(events).sum(&:score)).to be < 50
  end

  it 'keeps USER_MISMATCH diagnostic non-punitive' do
    events = [event(id: 1, at: '2026-07-10 10:00', diagnostic: { status: 'USER_MISMATCH' })]
    expect(detect(events, mode: :strict)).to be_empty
  end
end
# rubocop:enable Metrics, Layout/LineLength
