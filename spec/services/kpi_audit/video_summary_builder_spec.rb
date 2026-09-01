# frozen_string_literal: true

require_relative '../../support/hikvision_metadata_spec_helper'
require Rails.root.join('app/services/kpi_audit/configuration').to_s
require Rails.root.join('app/services/kpi_audit/video_link').to_s
require Rails.root.join('app/services/kpi_audit/video_summary').to_s
require Rails.root.join('app/services/kpi_audit/video_summary_builder').to_s

# rubocop:disable Metrics/BlockLength
RSpec.describe KpiAudit::VideoSummaryBuilder do
  let(:event_class) { Struct.new(:occurred_at, :video_diagnostic, keyword_init: true) }

  let(:zone) { Time.find_zone!('Vladivostok') }
  let(:configuration) do
    KpiAudit::Configuration.new(video: { pre_roll_seconds: 15, post_roll_seconds: 15,
                                         max_preview_duration_seconds: 1800,
                                         link_ttl_seconds: 3600 })
  end
  let(:queue) { double(id: 1, ipad_link: 'okean', name: 'Океан') }
  let(:ticket) { double(id: 114_974, ticket_number: 'К14', electronic_queue: queue) }
  let(:window) { double(window_number: 8) }
  let(:called) { double(elqueue_window: window) }
  let(:first_time) { zone.parse('2026-07-29 06:00:44') }
  let(:last_time) { zone.parse('2026-07-29 06:07:23') }
  let(:status) { 'EXACT' }
  let(:events) do
    [event_class.new(occurred_at: first_time,
                     video_diagnostic: { status: status, waiting_client: ticket, called: called }),
     event_class.new(occurred_at: last_time,
                     video_diagnostic: { status: status, waiting_client: ticket, called: called })]
  end
  let(:link_builder) { ->(payload) { "https://ais.example/kpi/video/#{payload[:camera_key]}" } }

  subject(:summary) do
    described_class.new(events: events, investigation_id: 'case-1', configuration: configuration,
                        link_builder: link_builder).call
  end

  it 'builds one primary AIS link from ticket, historical Called and mapped window' do
    expect(summary.available?).to eq(true)
    expect(summary.status).to eq('EXACT')
    expect(summary.window_number).to eq(8)
    expect(summary.camera_key).to eq(:zal1)
    expect(summary.channel).to eq(1)
    expect(summary.primary_link.label).to eq('Смотреть видео события')
    expect(summary.primary_link.type).to eq(:ais_video)
  end

  it 'builds metadata without routes and leaves primary link unpublished in PHASE A' do
    result = described_class.new(events: events, investigation_id: 'case-1', configuration: configuration).call

    expect(result.available?).to eq(true)
    expect(result.playback_available).to eq(true)
    expect(result.primary_link).to be_nil
    expect(result.explanation).to include('Пользовательская ссылка не опубликована')
  end

  it 'applies pre-roll and post-roll without UTC conversion' do
    expect(summary.range_start).to eq(zone.parse('2026-07-29 06:00:29'))
    expect(summary.range_end).to eq(zone.parse('2026-07-29 06:07:38'))
    expect(summary.range_start.strftime('%H:%M:%S')).to eq('06:00:29')
  end

  it 'returns a fallback camera as an alternative link' do
    allow(window).to receive(:window_number).and_return(7)

    expect(summary.camera_key).to eq(:zal2)
    expect(summary.alternative_links.map(&:camera_name)).to eq(['zal1'])
  end

  it 'does not create a link without a ticket' do
    allow(events.first).to receive(:video_diagnostic).and_return(status: 'NO_TICKET')
    allow(events.last).to receive(:video_diagnostic).and_return(status: 'NO_TICKET')

    expect(summary.primary_link).to be_nil
    expect(summary.available?).to eq(false)
    expect(summary.explanation).to eq('Талон электронной очереди не установлен.')
  end

  it 'does not create a link without historical Called' do
    allow(events.first).to receive(:video_diagnostic).and_return(status: 'NO_CALLED')
    allow(events.last).to receive(:video_diagnostic).and_return(status: 'NO_CALLED')

    expect(summary.primary_link).to be_nil
    expect(summary.available?).to eq(false)
    expect(summary.explanation).to eq('Историческое рабочее окно не установлено.')
  end

  context 'with USER_MISMATCH' do
    let(:status) { 'USER_MISMATCH' }

    it 'keeps video available and explains the diagnostic neutrally' do
      expect(summary.available?).to eq(true)
      expect(summary.confidence_score).to eq(70)
      expect(summary.explanation).to include('другим сотрудником')
      expect(summary.primary_link).not_to be_nil
    end
  end

  it 'contains no NVR credentials in URL, hashes or inspect output' do
    serialized = summary.to_h(diagnostics: true).inspect
    inspected = summary.inspect + summary.primary_link.inspect

    expect(summary.primary_link.url).not_to match(/password|admin|192\.168\.1\.88|rtsp/i)
    expect(serialized).not_to match(/password|authorization|rtsp/i)
    expect(inspected).not_to match(/password|authorization|rtsp/i)
  end

  it 'splits a long range explicitly instead of silently truncating it' do
    allow(events.last).to receive(:occurred_at).and_return(first_time + 31.minutes)

    expect(summary.range_end).to eq(first_time + 31.minutes + 15.seconds)
    expect(summary.diagnostics[:segmented]).to eq(true)
    expect(summary.diagnostics[:segments].size).to eq(2)
  end

  it 'deduplicates 22 events into one summary and one primary link' do
    repeated = Array.new(22) do |index|
      event_class.new(occurred_at: first_time + index.seconds,
                      video_diagnostic: { status: 'EXACT', waiting_client: ticket, called: called })
    end
    calls = 0
    builder = described_class.new(events: repeated, investigation_id: 'burst', configuration: configuration,
                                  link_builder: lambda { |_payload|
                                    calls += 1
                                    'https://ais.example/video'
                                  })

    result = builder.call
    expect(result).to be_a(KpiAudit::VideoSummary)
    expect(calls).to eq(1)
  end
end
# rubocop:enable Metrics/BlockLength
