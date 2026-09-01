# frozen_string_literal: true

module Hikvision
  # Resolves an electronic-queue window to its configured camera route.
  class CameraRouter
    Route = Struct.new(:queue_key, :window, :primary, :fallback, :nvr_name, keyword_init: true)

    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def self.for(queue:, window:, configuration: CameraCatalog.new)
      queue_config = configuration.electronic_queue(queue)
      window_number = Integer(window)
      route = queue_config.windows[window_number]
      unless route
        raise CameraCatalog::Error,
              "Hikvision camera route is not configured for queue #{queue_config.key.inspect}, window #{window_number}"
      end

      Route.new(
        queue_key: queue_config.key,
        window: window_number,
        primary: route.fetch(:primary).to_sym,
        fallback: route.fetch(:fallback).map(&:to_sym).freeze,
        nvr_name: queue_config.nvr_name
      )
    rescue ArgumentError, TypeError
      raise CameraCatalog::Error, "Invalid electronic queue window #{window.inspect}"
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
