# frozen_string_literal: true

# rubocop:disable Metrics

require_relative '../../support/kpi_audit_unit_helper'

RSpec.describe KpiAudit::VisitReconstructor do
  def event(id:, time:, client_id: 1, employee_id: 1, ticket_id: nil, serial: nil, device_id: nil)
    KpiAudit::Event.new(kind: :free_job, record: Struct.new(:id).new(id), occurred_at: time,
                        client_id: client_id, employee_id: employee_id, ticket_id: ticket_id,
                        serial: serial, device_id: device_id, monetary_amount: 0)
  end

  it 'does not merge two visits merely because client_id is equal' do
    events = [event(id: 1, time: Time.zone.parse('2026-07-01 10:00')),
              event(id: 2, time: Time.zone.parse('2026-07-02 10:00'))]
    expect(described_class.new(events: events, configuration: KPI_AUDIT_TEST_CONFIG).call.size).to eq(2)
  end

  it 'does not merge equal clients with different devices and tickets' do
    events = [event(id: 1, time: Time.zone.parse('2026-07-01 10:00'), ticket_id: 10, device_id: 1),
              event(id: 2, time: Time.zone.parse('2026-07-01 10:01'), ticket_id: 11, device_id: 2)]
    expect(described_class.new(events: events, configuration: KPI_AUDIT_TEST_CONFIG).call.size).to eq(2)
  end

  it 'uses equal serial as strong visit evidence' do
    events = [event(id: 1, time: Time.zone.parse('2026-07-01 10:00'), serial: 'ABC'),
              event(id: 2, time: Time.zone.parse('2026-07-01 10:05'), serial: 'abc')]
    visits = described_class.new(events: events, configuration: KPI_AUDIT_TEST_CONFIG).call
    expect(visits.size).to eq(1)
    expect(visits.first).to be_confirmed
  end
end
# rubocop:enable Metrics
