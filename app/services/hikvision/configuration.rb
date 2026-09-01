# frozen_string_literal: true

require "yaml"
require_relative 'configuration_error'

module Hikvision
  class Configuration
    Camera = Struct.new(:name, :channel, :main_stream, :substream, keyword_init: true)
    Nvr = Struct.new(
      :name,
      :host,
      :http_port,
      :rtsp_port,
      :user,
      :password,
      :archive_clock,
      :cameras,
      keyword_init: true
    )
    Selection = Struct.new(:department_key, :nvr, :camera, keyword_init: true)
    ElectronicQueue = Struct.new(
      :key, :name, :department_code, :nvr_name, :windows,
      keyword_init: true
    )

    def initialize(path: Rails.root.join("config", "hikvision.yml"), env: ENV)
      @path = Pathname(path)
      @env = env
      @data = load_data
    end

    def resolve(department:, camera: nil)
      department_code = department.respond_to?(:code) ? department.code : department.to_s
      department_key, department_data = find_department(department_code)
      camera_name = camera.presence || department_data["default_event_camera"].presence

      if camera_name.blank?
        raise Error,
          "Hikvision camera is not specified for department #{department_code.inspect}; " \
          "pass camera: explicitly or configure default_event_camera"
      end

      nvr = nvr(department_data.fetch("nvr"))
      camera_config = nvr.cameras[camera_name.to_s]
      unless camera_config
        raise Error,
          "Unknown Hikvision camera #{camera_name.inspect} for department #{department_code.inspect}"
      end

      Selection.new(department_key: department_key, nvr: nvr, camera: camera_config)
    end

    def nvr(name)
      name = name.to_s
      config = @data.fetch("nvrs", {})[name]
      raise Error, "Unknown Hikvision NVR #{name.inspect}" unless config

      cameras = config.fetch("cameras", {}).each_with_object({}) do |(camera_name, camera_data), result|
        result[camera_name] = Camera.new(
          name: camera_name,
          channel: Integer(camera_data.fetch("channel")),
          main_stream: Integer(camera_data.fetch("main_stream")),
          substream: optional_integer(camera_data["substream"])
        )
      end

      Nvr.new(
        name: name,
        host: required_env(config.fetch("host_env")),
        http_port: env_integer(config.fetch("http_port_env"), default: 80),
        rtsp_port: env_integer(config.fetch("rtsp_port_env"), default: 554),
        user: required_env(config.fetch("user_env")),
        password: required_env(config.fetch("password_env")),
        archive_clock: config.fetch("archive_clock", "local_wall_clock_as_z"),
        cameras: cameras
      )
    rescue KeyError, ArgumentError => e
      raise Error, "Invalid Hikvision NVR #{name.inspect} configuration: #{e.message}"
    end


    def electronic_queue(key)
      key = key.to_s
      config = @data.fetch("electronic_queues", {})[key]
      raise Error, "Unknown Hikvision electronic queue #{key.inspect}" unless config

      nvr_name = config.fetch("nvr").to_s
      camera_names = @data.fetch("nvrs", {}).dig(nvr_name, "cameras")
      raise Error, "Unknown Hikvision NVR #{nvr_name.inspect}" unless camera_names

      windows = config.fetch("windows", {}).each_with_object({}) do |(number, route), result|
        primary = route.fetch("primary").to_s
        fallback = Array(route["fallback"]).map(&:to_s)
        (fallback + [primary]).each do |camera_name|
          unless camera_names.key?(camera_name)
            raise Error, "Unknown Hikvision camera #{camera_name.inspect} for queue #{key.inspect}"
          end
        end
        result[Integer(number)] = {primary: primary, fallback: fallback}.freeze
      end

      ElectronicQueue.new(
        key: key,
        name: config.fetch("name"),
        department_code: config.fetch("department_code").to_s,
        nvr_name: nvr_name,
        windows: windows.freeze
      )
    rescue KeyError, ArgumentError => e
      raise Error, "Invalid Hikvision electronic queue #{key.inspect} configuration: #{e.message}"
    end

    private

    def load_data
      content = YAML.safe_load(@path.read, aliases: false)
      content.is_a?(Hash) ? content : {}
    rescue Errno::ENOENT, Psych::Exception => e
      raise Error, "Cannot load Hikvision configuration #{@path}: #{e.message}"
    end

    def find_department(code)
      missing_code_envs = []
      match = @data.fetch("departments", {}).find do |_key, config|
        configured_code = config["code"].presence
        if configured_code.blank? && config["code_env"].present?
          configured_code = @env[config["code_env"]].presence
          missing_code_envs << config["code_env"] if configured_code.blank?
        end
        configured_code == code
      end
      return match if match

      if missing_code_envs.any?
        raise Error, "Missing Hikvision department ENV: #{missing_code_envs.uniq.join(", ")}"
      end

      raise Error, "Hikvision is not configured for department code #{code.inspect}"
    end

    def required_env(name)
      @env[name].presence || raise(Error, "Missing required Hikvision ENV #{name}")
    end

    def env_integer(name, default:)
      value = @env[name].presence || default
      Integer(value)
    end

    def optional_integer(value)
      value.present? ? Integer(value) : nil
    end
  end
end
