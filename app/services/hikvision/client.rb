# frozen_string_literal: true

require "fileutils"
require "httparty"
require "nokogiri"
require "open3"
require "uri"

module Hikvision
  class Client
    class Error < StandardError; end

    class ResponseError < Error; end

    class DownloadError < Error; end

    class CommandRunner
      def call(arguments)
        _stdout, _stderr, status = Open3.capture3(*arguments)
        status.success?
      end
    end

    def initialize(nvr:, http_client: HTTParty, command_runner: CommandRunner.new)
      @nvr = nvr
      @http_client = http_client
      @command_runner = command_runner
    end

    def snapshot(channel, time: nil, output_path: nil)
      raise ArgumentError, "historical snapshot is not supported yet" if time.present?

      camera = camera_for(channel)
      response = get("/ISAPI/Streaming/channels/#{camera.main_stream}/picture")
      content_type = response.headers["content-type"].to_s
      unless response.code.to_i == 200 && content_type.start_with?("image/jpeg")
        raise ResponseError, "Hikvision snapshot failed with HTTP #{response.code}"
      end

      return response.body unless output_path

      path = Pathname(output_path)
      FileUtils.mkdir_p(path.dirname)
      path.binwrite(response.body)
      path
    end

    def available?(channel)
      channel = Integer(channel)
      camera_for(channel)
      response = get("/ISAPI/ContentMgmt/InputProxy/channels/status")
      return false unless response.code.to_i == 200

      document = Nokogiri::XML(response.body)
      status = document.xpath('//*[local-name()="InputProxyChannelStatus"]').find do |node|
        node.at_xpath('./*[local-name()="id"]')&.text.to_i == channel
      end
      status&.at_xpath('./*[local-name()="online"]')&.text == "true"
    rescue ArgumentError, ResponseError, HTTParty::Error, SocketError, SystemCallError, Timeout::Error
      false
    end

    def download_clip(channel:, start_time:, end_time:, output_path: nil)
      channel = Integer(channel)
      camera_for(channel)
      duration = end_time - start_time
      raise ArgumentError, "end_time must be later than start_time" unless duration.positive?

      output_path ||= default_clip_path(channel, start_time, end_time)
      output_path = Pathname(output_path)
      FileUtils.mkdir_p(output_path.dirname)

      arguments = [
        "ffmpeg", "-v", "quiet", "-nostdin", "-y",
        "-rtsp_transport", "tcp", "-i", playback_url(channel, start_time, end_time),
        "-t", duration.to_i.to_s, "-map", "0", "-c", "copy", output_path.to_s
      ]

      success = @command_runner.call(arguments)
      unless success && output_path.file? && output_path.size.positive?
        raise DownloadError, "Hikvision archive download failed for channel #{channel}"
      end

      output_path
    rescue Errno::ENOENT
      raise DownloadError, "ffmpeg is not available"
    end

    private

    def get(path)
      @http_client.get(
        "http://#{@nvr.host}:#{@nvr.http_port}#{path}",
        digest_auth: {username: @nvr.user, password: @nvr.password},
        timeout: 20,
        open_timeout: 5,
        headers: {"Accept" => "*/*"}
      )
    rescue => e
      raise ResponseError, "Hikvision GET failed: #{e.class}"
    end

    def camera_for(channel)
      channel = Integer(channel)
      @nvr.cameras.values.find { |camera| camera.channel == channel } ||
        raise(ArgumentError, "channel #{channel} is not configured for NVR #{@nvr.name}")
    end

    def playback_url(channel, start_time, end_time)
      track_id = channel * 100 + 1
      user = encode_userinfo(@nvr.user)
      password = encode_userinfo(@nvr.password)
      start_value = ArchiveTimestamp.call(start_time)
      end_value = ArchiveTimestamp.call(end_time)

      "rtsp://#{user}:#{password}@#{@nvr.host}:#{@nvr.rtsp_port}/Streaming/tracks/#{track_id}/" \
        "?starttime=#{start_value}&endtime=#{end_value}"
    end

    def encode_userinfo(value)
      URI.encode_www_form_component(value.to_s).gsub("+", "%20")
    end

    def default_clip_path(channel, start_time, end_time)
      start_value = start_time.in_time_zone(ArchiveTimestamp::ZONE).strftime("%Y%m%d_%H%M%S")
      end_value = end_time.in_time_zone(ArchiveTimestamp::ZONE).strftime("%Y%m%d_%H%M%S")
      Rails.root.join(
        "tmp", "hikvision", "clips",
        "channel_#{format("%02d", channel)}_#{start_value}_#{end_value}.mp4"
      )
    end
  end
end
