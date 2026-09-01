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
    end

    def video
      @episode = find_cached_episode
      @video = @episode.video_summary
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
  end
end
