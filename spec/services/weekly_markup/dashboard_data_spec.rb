require 'rails_helper'

RSpec.describe WeeklyMarkup::DashboardData do
  def metric(date, revenue, cost)
    profit = BigDecimal(revenue) - BigDecimal(cost)
    {'date' => date, 'revenue' => revenue, 'cost' => cost, 'gross_profit' => profit.to_s('F'),
     'cash' => revenue, 'noncash' => '0.00', 'unallocated' => '0.00'}
  end

  it 'uses the newest successful version per day and calculates ratios from totals' do
    old_day = metric('2026-08-11', '100.00', '60.00')
    new_day = metric('2026-08-11', '120.00', '80.00')
    [old_day, new_day].each_with_index do |day, index|
      WeeklyMarkupImport.create!(delivery_id: (index.zero? ? 'a' : 'b') * 64,
        period_from: '2026-08-11', period_to: '2026-08-11', calculated_at: Time.utc(2026, 9, 10 + index),
        methodology_version: 'weekly-markup-1.0.0', status: 'successful',
        payload: {'totals' => {'days' => [day]}, 'branches' => [], 'discrepancies' => []})
    end
    result = described_class.new(from: Date.new(2026, 8, 11), to: Date.new(2026, 8, 11)).call
    expect(result[:totals][:revenue]).to eq(BigDecimal('120'))
    expect(result[:totals][:gross_margin]).to eq(BigDecimal('40') / BigDecimal('120'))
    expect(result[:weeks].first[:incomplete]).to eq(true)
  end
end
