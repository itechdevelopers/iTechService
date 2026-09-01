# frozen_string_literal: true

require 'rails_helper'

# rubocop:disable Metrics/BlockLength
RSpec.describe KpiAudit::EpisodesController, type: :controller do
  render_views

  let(:user) { create(:user, :superadmin) }
  let(:departments) { double(order: [user.department]) }

  before do
    sign_in user
    allow(Department).to receive(:real).and_return(departments)
  end

  describe 'GET index' do
    it 'does not run Analyzer while opening the page' do
      expect(KpiAudit::Analyzer).not_to receive(:call)

      get :index

      expect(response).to have_http_status(:ok)
      expect(assigns(:episodes)).to be_nil
      expect(response.body).to include('Обычный — показывает только эпизоды')
      expect(response.body).to include('Строгий — дополнительно показывает эпизоды')
    end
  end

  describe 'POST analyze' do
    it 'runs Analyzer only after the explicit action and caches presentation episodes' do
      analysis = double(investigations: [])
      allow(KpiAudit::ReadOnlyRunner).to receive(:call) { |&block| block.call }
      expect(KpiAudit::Analyzer).to receive(:call).with(
        department_id: user.department_id, date_from: Date.new(2026, 7, 29),
        date_to: Date.new(2026, 7, 29), mode: :strict
      ).and_return(analysis)

      post :analyze, params: { analysis: { department_id: user.department_id, date_from: '2026-07-29',
                                           date_to: '2026-07-29', mode: 'strict' } }

      expect(response).to have_http_status(:ok)
      expect(assigns(:episodes)).to eq([])
      expect(assigns(:run_id)).to be_present
    end
  end

  describe 'GET show' do
    it 'reads the explicit run cache without running Analyzer again' do
      episode = KpiAudit::Episode.new(
        id: 'episode-1', summary: 'Основание для проверки', employee: {},
        visit_profile: { started_at: Time.zone.now, ended_at: Time.zone.now }, signals: [],
        risk_score: 25, risk_level: :moderate, confidence: { score: 80 }, timeline: [],
        economic_outcome: {}, video_summary: {}, related_records: [], limitations: []
      )
      Rails.cache.write("kpi-audit:runs:user:#{user.id}:test-run", [episode])
      expect(KpiAudit::Analyzer).not_to receive(:call)

      get :show, params: { id: episode.id, run_id: 'test-run' }

      expect(response).to have_http_status(:ok)
      expect(assigns(:episode).id).to eq(episode.id)
    end

    it 'redirects when a cached run has expired instead of raising' do
      get :show, params: { id: 'missing', run_id: 'expired-run' }

      expect(response).to redirect_to(kpi_audit_episodes_path)
    end
  end

  describe 'GET clip' do
    let(:episode) do
      KpiAudit::Episode.new(
        id: 'episode-video', summary: 'Основание для проверки', employee: {},
        visit_profile: {}, signals: [], risk_score: 25, risk_level: :moderate,
        confidence: { score: 80 }, timeline: [], economic_outcome: {},
        video_summary: { available: true, queue_key: 'okean', ticket_id: 114_974,
                         camera_key: 'zal1', channel: 1,
                         range_start: Time.zone.parse('2026-08-31 17:00:30'),
                         range_end: Time.zone.parse('2026-08-31 17:02:32') },
        related_records: [], limitations: []
      )
    end

    it 'generates a protected clip only after an explicit request' do
      Rails.cache.write("kpi-audit:runs:user:#{user.id}:video-run", [episode])
      service = instance_double(KpiAudit::VideoClipService, call: Rails.root.join('tmp', 'clip.mp4').to_s)
      allow(KpiAudit::VideoClipService).to receive(:new).and_return(service)
      allow(controller).to receive(:send_file)

      get :clip, params: { id: episode.id, run_id: 'video-run' }

      expect(response).to have_http_status(:ok)
      expect(service).to have_received(:call)
    end

    it 'does not invoke NVR service for unsupported queues' do
      unsupported = episode.to_h.merge(video_summary: episode.video_summary.merge(queue_key: 'other'))
      Rails.cache.write("kpi-audit:runs:user:#{user.id}:unsupported", [KpiAudit::Episode.new(**unsupported)])
      expect(KpiAudit::VideoClipService).not_to receive(:new)

      get :clip, params: { id: episode.id, run_id: 'unsupported' }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'authorization' do
    let(:user) { create(:user, :software) }

    it 'denies access to an employee without an existing management role' do
      get :index

      expect(response).to redirect_to(root_path)
    end
  end
end
# rubocop:enable Metrics/BlockLength
