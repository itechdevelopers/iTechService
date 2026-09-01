# frozen_string_literal: true

require 'yaml'
require_relative 'configuration_error'

module Hikvision
  # Credential-free queue and camera metadata used by passive analysis.
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  class CameraCatalog
    class Error < Configuration::Error; end

    Camera = Struct.new(:name, :channel, :main_stream, :substream, keyword_init: true)
    Queue = Struct.new(:key, :name, :department_code, :nvr_name, :windows, keyword_init: true)

    def initialize(path: Rails.root.join('config', 'hikvision.yml'))
      @data = YAML.safe_load(Pathname(path).read, aliases: false) || {}
    rescue Errno::ENOENT, Psych::Exception => e
      raise Error, "Cannot load camera catalog: #{e.message}"
    end

    def electronic_queue(key)
      key = key.to_s
      data = @data.fetch('electronic_queues', {})[key]
      raise Error, "Unknown Hikvision electronic queue #{key.inspect}" unless data

      windows = data.fetch('windows', {}).each_with_object({}) do |(number, route), result|
        result[Integer(number)] = {
          primary: route.fetch('primary').to_s,
          fallback: Array(route['fallback']).map(&:to_s).freeze
        }.freeze
      end
      validate_cameras!(data.fetch('nvr'), windows)
      Queue.new(key: key, name: data.fetch('name'), department_code: data.fetch('department_code').to_s,
                nvr_name: data.fetch('nvr').to_s, windows: windows.freeze)
    rescue KeyError, ArgumentError => e
      raise Error, "Invalid camera route for queue #{key.inspect}: #{e.message}"
    end

    def camera(nvr_name, camera_name)
      data = @data.fetch('nvrs', {}).fetch(nvr_name.to_s).fetch('cameras', {}).fetch(camera_name.to_s)
      Camera.new(name: camera_name.to_s, channel: Integer(data.fetch('channel')),
                 main_stream: Integer(data.fetch('main_stream')),
                 substream: data['substream'].present? ? Integer(data['substream']) : nil)
    rescue KeyError, ArgumentError => e
      raise Error, "Invalid camera metadata: #{e.message}"
    end

    private

    def validate_cameras!(nvr_name, windows)
      windows.each_value do |route|
        ([route[:primary]] + route[:fallback]).each { |key| camera(nvr_name, key) }
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
