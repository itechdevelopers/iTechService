# frozen_string_literal: true

module KpiAudit
  # Manual, authorized KPI audit UI. Analyzer runs only from the analyze action.
  # rubocop:disable Metrics/ClassLength, Metrics/AbcSize, Metrics/MethodLength
  class EpisodesController < ApplicationController
    CACHE_TTL = 30.minutes
    SEGMENT_SECONDS = 120
    RUN_STORE = RunStore.new

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
      RUN_STORE.write(current_user.id, @run_id, @episodes, expires_in: CACHE_TTL)
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
      @segments = video_segments(@video)
    rescue ActiveRecord::RecordNotFound
      redirect_to kpi_audit_episodes_path, alert: 'Результат проверки больше недоступен. Запустите проверку повторно.'
    end

    def clip
      @episode = find_cached_episode
      summary = @episode.video_summary
      unless summary[:queue_key].to_s == 'okean'
        return render plain: 'Просмотр видео для этого подразделения пока не подключён.', status: :not_found
      end

      segment = selected_segment(summary)
      return render plain: 'Недопустимый фрагмент видео.', status: :not_found unless segment

      path = VideoClipService.new(payload: clip_payload(summary, segment)).call
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
      episodes = RUN_STORE.read(current_user.id, params.fetch(:run_id))
      raise ActiveRecord::RecordNotFound unless episodes

      episodes.find { |episode| episode.id == params[:id] } || raise(ActiveRecord::RecordNotFound)
    end

    def selected_segment(summary)
      video_segments(summary).fetch(Integer(params.fetch(:segment, 0)))
    rescue ArgumentError, IndexError, TypeError
      nil
    end

    def video_segments(summary)
      diagnostics = (summary[:diagnostics] || {}).deep_symbolize_keys
      source = Array(diagnostics[:segments])
      source = [{ start_time: summary[:range_start], end_time: summary[:range_end] }] if source.empty?
      source.flat_map { |segment| split_segment(segment) }
    end

    def split_segment(segment)
      start_time = Time.iso8601(segment[:start_time].to_s)
      end_time = Time.iso8601(segment[:end_time].to_s)
      result = []
      cursor = start_time
      while cursor < end_time
        finish = [cursor + SEGMENT_SECONDS, end_time].min
        result << { start_time: cursor.iso8601, end_time: finish.iso8601 }
        cursor = finish
      end
      result
    rescue ArgumentError, TypeError
      []
    end

    def clip_payload(summary, segment)
      diagnostics = (summary[:diagnostics] || {}).deep_symbolize_keys
      diagnostics.merge(
        investigation_id: @episode.id, ticket_id: summary[:ticket_id], nvr_name: 'okean',
        queue_key: summary[:queue_key], camera_key: summary[:camera_key], channel: summary[:channel],
        range_start: segment.fetch(:start_time), range_end: segment.fetch(:end_time)
      )
    end
  end
  # rubocop:enable Metrics/ClassLength, Metrics/AbcSize, Metrics/MethodLength
end
