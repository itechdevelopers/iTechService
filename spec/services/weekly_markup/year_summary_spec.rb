require 'rails_helper'

RSpec.describe WeeklyMarkup::YearSummary do
  it 'uses fully and partially closed months and exposes the previous month markup' do
    january = {from: Date.new(2026, 1, 1), to: Date.new(2026, 1, 31), status: 'Закрыт',
               eligible_for_yearly_markup: true,
               totals: {revenue: BigDecimal('120'), cost: BigDecimal('100'), gross_profit: BigDecimal('20'), markup: BigDecimal('0.2')}}
    august = {from: Date.new(2026, 8, 1), to: Date.new(2026, 8, 31), status: 'Закрыт, но не до конца',
              eligible_for_yearly_markup: true,
              totals: {revenue: BigDecimal('240'), cost: BigDecimal('200'), gross_profit: BigDecimal('40'), markup: BigDecimal('0.2')}}
    september = {from: Date.new(2026, 9, 1), to: Date.new(2026, 9, 30), status: 'Предварительный',
                 eligible_for_yearly_markup: false,
                 totals: {revenue: BigDecimal('1000'), cost: BigDecimal('1'), gross_profit: BigDecimal('999'), markup: BigDecimal('999')}}
    dashboard = instance_double(WeeklyMarkup::DashboardData, call: {months: [january, august, september]})
    allow(WeeklyMarkup::DashboardData).to receive(:new).and_return(dashboard)
    allow(Date).to receive(:current).and_return(Date.new(2026, 9, 11))

    result = described_class.new(year: 2026).call

    expect(result[:closed_months]).to eq(2)
    expect(result[:markup]).to eq(BigDecimal('0.2'))
    expect(result[:previous_month]).to include(from: Date.new(2026, 8, 1), status: 'Закрыт, но не до конца', markup: BigDecimal('0.2'))
  end
end
