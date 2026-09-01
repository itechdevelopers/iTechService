# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KpiAudit::EpisodesHelper do
  it 'formats Russian durations without fractional seconds' do
    expect(helper.human_duration(81.399728)).to eq('1 минуту и 21 секунду')
  end

  it 'builds a human reason for a ticket KPI group' do
    episode = double(video_summary: { ticket_number: 'К14' }, visit_profile: { kpi_count: 6 },
                     signals: [{ code: :multiple_kpi, description: '6 KPI в рамках одного восстановленного визита' },
                               { code: :confirmed_ticket, description: 'Один подтверждённый ticket_id' }])

    expect(helper.kpi_episode_reasons(episode).first[:description]).to eq(
      '1 талон электронной очереди и 6 операций, влияющих на выполнение плана, в рамках этого талона'
    )
  end

  it 'formats a free-service burst reason from timeline timestamps' do
    episode = double(timeline: [{ type: :free_service_created, occurred_at: Time.zone.parse('2026-07-29 06:00:00') },
                                { type: :free_service_created, occurred_at: Time.zone.parse('2026-07-29 06:01:21.399') }])
    signal = { code: :burst, description: '5 Бесплатных сервисов за 1 minute and 21.399728 seconds' }

    expect(helper.kpi_free_service_reason(episode, signal)).to eq('5 бесплатных сервисов за 1 минуту и 21 секунду')
  end
end
