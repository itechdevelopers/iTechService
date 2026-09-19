require 'rails_helper'

RSpec.describe WeeklyMarkup::Import do
  let(:day) do
    {'date' => '2026-08-11', 'revenue' => '100.00', 'cost' => '60.00', 'gross_profit' => '40.00',
     'cash' => '70.00', 'noncash' => '20.00', 'unallocated' => '10.00'}
  end
  let(:report) do
    {'schema_version' => 'ice-weekly-markup-1.0', 'methodology_version' => 'weekly-markup-1.0.0',
     'calculated_at' => '2026-09-10T10:00:00Z', 'period' => {'from' => '2026-08-11', 'to' => '2026-08-11'},
     'source' => {'read_only' => true, 'http_methods' => ['GET']}, 'checks' => {'passed' => true},
     'totals' => day.merge('days' => [day]),
     'branches' => [{'warehouse_id' => 'branch-1', 'name' => 'Филиал', 'total' => day, 'days' => [day]}]}
  end
  let(:delivery_id) { 'a' * 64 }

  it 'imports once and treats a repeated delivery as duplicate' do
    first, first_status = described_class.call(delivery_id: delivery_id, report: report)
    second, second_status = described_class.call(delivery_id: delivery_id, report: report)
    expect(first_status).to eq(:created)
    expect(second_status).to eq(:duplicate)
    expect(second.id).to eq(first.id)
    expect(WeeklyMarkupImport.where(delivery_id: delivery_id).count).to eq(1)
  end

  it 'rejects a report whose payments do not reconcile' do
    report['totals']['cash'] = '71.00'
    report['totals']['days'].first['cash'] = '71.00'
    expect { described_class.call(delivery_id: delivery_id, report: report) }
      .to raise_error(WeeklyMarkup::Import::InvalidReport, /payments/)
  end


  it 'validates exact product analytics totals' do
    report['sales_analytics'] = {'products' => [{
      'item_id' => 'item-1', 'days' => [{'date' => '2026-08-11', 'operation_count' => '1', 'quantity' => '1',
        'revenue' => '100.00', 'cost' => '60.00', 'gross_profit' => '40.00'}],
      'total' => {'operation_count' => '1', 'quantity' => '1', 'revenue' => '100.00', 'cost' => '60.00', 'gross_profit' => '40.00'}
    }]}
    expect { described_class.call(delivery_id: delivery_id, report: report) }.not_to raise_error
  end
end
