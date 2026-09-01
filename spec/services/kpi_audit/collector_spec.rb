# frozen_string_literal: true

require_relative '../../support/kpi_audit_unit_helper'
require_relative '../../../app/services/kpi_audit/collector'

RSpec.describe KpiAudit::Collector do
  it 'uses the production queue_name contract in the ticket snapshot' do
    queue = double(ipad_link: 'okean', queue_name: 'Первая речка')
    ticket = double(id: 114_974, ticket_number: 'К14', ticket_issued_at: nil,
                    ticket_served_at: nil, electronic_queue: queue)
    collector = described_class.new(department: double(id: 2), date_from: Date.new(2026, 7, 29),
                                    date_to: Date.new(2026, 7, 29))
    allow(collector).to receive(:video_diagnostic)
      .and_return(status: 'EXACT', waiting_client: ticket, called: nil)

    snapshot = collector.send(:ticket_snapshot, double)

    expect(snapshot[:queue_name]).to eq('Первая речка')
  end
end
