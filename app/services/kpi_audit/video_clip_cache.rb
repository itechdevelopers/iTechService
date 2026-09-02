# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'open3'
require 'securerandom'

module KpiAudit
  # Small TTL cache that deduplicates lazily generated investigation clips.
  class VideoClipCache
    def initialize(root: Rails.root.join('tmp', 'kpi_audit_video'), ttl: 1.hour, validator: nil)
      @root = Pathname(root)
      @ttl = ttl
      @validator = validator || method(:valid_mp4?)
    end

    def fetch(key, &block)
      path = @root.join("#{Digest::SHA256.hexdigest(key)}.mp4")
      FileUtils.mkdir_p(@root)
      lock_path = @root.join("#{Digest::SHA256.hexdigest(key)}.lock")
      with_lock(lock_path) { publish_or_reuse(path, &block) }
    end

    def publish_or_reuse(path, &block)
      return path if cached?(path)

      cleanup_expired
      publish(path, &block)
    end

    def with_lock(lock_path)
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        yield
      ensure
        lock.flock(File::LOCK_UN)
      end
    end

    def cleanup_expired
      @root.glob('*.mp4').each do |path|
        next unless path.mtime <= @ttl.ago

        FileUtils.rm_f(path)
        FileUtils.rm_f(marker_path(path))
      end
      @root.glob('*.part-*').each { |path| FileUtils.rm_f(path) if path.mtime <= @ttl.ago }
    end

    private

    def cached?(path)
      marker = marker_path(path)
      return false unless path.file? && path.mtime > @ttl.ago
      return marker.mtime > @ttl.ago if marker.file?
      return false unless @validator.call(path)

      FileUtils.touch(marker)
      true
    end

    def publish(path, &block)
      temporary_path = @root.join("#{path.basename('.mp4')}.part-#{Process.pid}-#{SecureRandom.hex(8)}.mp4")
      published = false
      block.call(temporary_path)
      raise 'invalid video cache artifact' unless @validator.call(temporary_path)

      File.rename(temporary_path, path)
      published = true
      FileUtils.touch(marker_path(path))
      path
    ensure
      FileUtils.rm_f(temporary_path) if temporary_path && !published
    end

    def marker_path(path)
      Pathname("#{path}.valid")
    end

    def valid_mp4?(path)
      return false unless path.file? && path.size.positive?

      _stdout, _stderr, status = Open3.capture3(
        'ffprobe', '-v', 'error', '-show_entries', 'format=format_name',
        '-of', 'default=noprint_wrappers=1:nokey=1', path.to_s
      )
      status.success?
    rescue SystemCallError
      false
    end
  end
end
