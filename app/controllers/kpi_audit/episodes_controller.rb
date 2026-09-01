# frozen_string_literal: true

module KpiAudit
  # Manual, authorized KPI audit UI. Analyzer runs only from the analyze action.
  class EpisodesController < ApplicationController
    CACHE_TTL = 30.minutes

    before_action :authorize_kpi_audit
    before_action :load_departments, only: %i[index analyze]

    def index
      @analysis_params = default_analysis_params
      @episodes = nil
    end

    def analyze
      @analysis_params = normalized_analysis_params
      @episodes = EpisodeBuilder.call(ReadOnlyRunner.call { Analyzer.call(**@analysis_params) }.investigations)
      @run_id = SecureRandom.hex(24)
      Rails.cache.write(cache_key(@run_id), @episodes, expires_in: CACHE_TTL)
      render :index
    rescue ArgumentError, ActiveRecord::RecordNotFound => e
      @episodes = nil
      flash.now[:alert] = e.message
      render :index, status: :unprocessable_entity
    end

    def show
      @episode = find_cached_episode
    rescue ActiveRecord::RecordNotFound
      redirect_to kpi_audit_episodes_path, alert: 'Результат проверки больше недоступен. Запустите проверку повторно.'
    end

    def video
      @episode = find_cached_episode
      @video = @episode.video_summary
    rescue ActiveRecord::RecordNotFound
      redirect_to kpi_audit_episodes_path, alert: 'Результат проверки больше недоступен. Запустите проверку повторно.'
    end

    def clip
      @episode = find_cached_episode
      summary = @episode.video_summary
      unless summary[:queue_key].to_s == 'okean'
        return render plain: 'Просмотр видео для этого подразделения пока не подключён.', status: :not_found
      end

      path = VideoClipService.new(payload: clip_payload(summary)).call
      send_file path, type: 'video/mp4', disposition: 'inline', filename: 'kpi-audit-video.mp4'
    rescue ActiveRecord::RecordNotFound
      redirect_to kpi_audit_episodes_path, alert: 'Результат проверки больше недоступен. Запустите проверку повторно.'
    rescue Hikvision::Client::Error, Hikvision::Configuration::Error, ArgumentError, SystemCallError => e
      Rails.logger.warn("[KpiAudit video] unavailable user_id=#{current_user.id} error=#{e.class.name}")
      render plain: 'Не удалось получить видеозапись.', status: :service_unavailable
    end

    private

    def authorize_kpi_audit
      authorize :kpi_audit, "#{action_name}?"
    end

    def load_departments
      @departments = Department.real.order(:name)
    end

    def default_analysis_params
      { department_id: current_department.id, date_from: Date.current.beginning_of_month,
        date_to: Date.current, mode: :normal }
    end

    def normalized_analysis_params
      values = params.require(:analysis).permit(:department_id, :date_from, :date_to, :mode)
      mode = values.fetch(:mode, 'normal').to_sym
      raise ArgumentError, 'Неизвестный режим проверки.' unless Analyzer::MODES.include?(mode)

      { department_id: Integer(values.fetch(:department_id)),
        date_from: Date.iso8601(values.fetch(:date_from)), date_to: Date.iso8601(values.fetch(:date_to)),
        mode: mode }
    rescue KeyError, Date::Error, TypeError
      raise ArgumentError, 'Проверьте подразделение и период.'
    end

    def find_cached_episode
      episodes = Rails.cache.read(cache_key(params.fetch(:run_id)))
      raise ActiveRecord::RecordNotFound unless episodes

      episodes.find { |episode| episode.id == params[:id] } || raise(ActiveRecord::RecordNotFound)
    end

    def cache_key(run_id)
      "kpi-audit:runs:user:#{current_user.id}:#{run_id}"
    end

    def clip_payload(summary)
      diagnostics = (summary[:diagnostics] || {}).deep_symbolize_keys
      diagnostics.merge(
        investigation_id: @episode.id,
        ticket_id: summary[:ticket_id],
        nvr_name: 'okean',
        queue_key: summary[:queue_key],
        camera_key: summary[:camera_key],
        channel: summary[:channel],
        range_start: iso8601(summary[:range_start]),
        range_end: iso8601(summary[:range_end])
      )
    end

    def iso8601(value)
      value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
    end
  end
end
