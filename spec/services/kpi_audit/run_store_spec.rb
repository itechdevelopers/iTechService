# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KpiAudit::RunStore do
  let(:redis) { instance_double(Redis) }
  let(:store) { described_class.new(redis: redis) }

  it 'stores and reads a user-isolated run with its TTL' do
    value = [{ id: 'episode-1' }]
    expect(redis).to receive(:set).with('kpi-audit:runs:user:42:run-1', anything, ex: 1_800)
    store.write(42, 'run-1', value, expires_in: 30.minutes)

    allow(redis).to receive(:get).with('kpi-audit:runs:user:42:run-1').and_return(Marshal.dump(value))
    expect(store.read(42, 'run-1')).to eq(value)
  end

  it 'does not read another user\'s run' do
    expect(redis).to receive(:get).with('kpi-audit:runs:user:8:run-1').and_return(nil)
    expect(store.read(8, 'run-1')).to be_nil
  end
end
