# frozen_string_literal: true

require_relative '../../support/hikvision_metadata_spec_helper'

RSpec.describe Hikvision::CameraRouter do
  subject(:route) { described_class.for(queue: 'okean', window: window) }

  { 1 => [:zal6, []], 3 => [:zal6, [:zal3]], 7 => [:zal2, [:zal1]], 9 => [:zal1, []] }.each do |number, expected|
    context "for window #{number}" do
      let(:window) { number.to_s }

      it 'returns the configured primary and fallback cameras' do
        expect(route.primary).to eq(expected[0])
        expect(route.fallback).to eq(expected[1])
      end
    end
  end

  it 'rejects an unknown queue' do
    expect do
      described_class.for(queue: 'unknown', window: 1)
    end.to raise_error(Hikvision::Configuration::Error, /Unknown Hikvision electronic queue/)
  end

  it 'rejects an unknown window without guessing a camera' do
    expect do
      described_class.for(queue: 'okean', window: 10)
    end.to raise_error(Hikvision::Configuration::Error, /window 10/)
  end
end
