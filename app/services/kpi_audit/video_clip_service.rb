# frozen_string_literal: true

module KpiAudit
  # Downloads one validated archive fragment only after an explicit user action.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  class VideoClipService
    def initialize(payload:, configuration: Configuration.load,
                   hikvision_configuration: Hikvision::Configuration.new,
                   cache: nil, client_factory: ->(nvr) { Hikvision::Client.new(nvr: nvr) })
      @payload = payload.deep_symbolize_keys
      @configuration = configuration
      @hikvision_configuration = hikvision_configuration
      @cache = cache || VideoClipCache.new(ttl: configuration.fetch(:video, :clip_ttl_seconds).seconds)
      @client_factory = client_factory
    end

    def call
      validate_payload!
      nvr = @hikvision_configuration.nvr(@payload.fetch(:nvr_name))
      camera = nvr.cameras.fetch(@payload.fetch(:camera_key).to_s)
      raise ArgumentError, 'camera channel mismatch' unless camera.channel == Integer(@payload.fetch(:channel))

      start_time = Time.iso8601(@payload.fetch(:range_start))
      end_time = Time.iso8601(@payload.fetch(:range_end))
      cache_key = [camera.name, camera.channel, start_time.iso8601, end_time.iso8601].join(':')
      @cache.fetch(cache_key) do |path|
        downloaded = @client_factory.call(nvr).download_clip(channel: camera.channel,
                                                             start_time: start_time,
                                                             end_time: end_time,
                                                             output_path: path)
        FileUtils.mv(downloaded, path) unless Pathname(downloaded) == path
      end
    end

    private

    def validate_payload!
      required = %i[investigation_id ticket_id nvr_name camera_key channel range_start range_end]
      missing = required.reject { |key| @payload[key].present? }
      raise ArgumentError, "incomplete video context: #{missing.join(', ')}" if missing.any?

      duration = Time.iso8601(@payload[:range_end]) - Time.iso8601(@payload[:range_start])
      max = @configuration.fetch(:video, :max_preview_duration_seconds)
      raise ArgumentError, 'video range must be positive' unless duration.positive?
      raise ArgumentError, 'video range requires segmented playback' if duration > max
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
