# frozen_string_literal: true

require 'digest'
require 'fileutils'

module KpiAudit
  # Small TTL cache that deduplicates lazily generated investigation clips.
  class VideoClipCache
    def initialize(root: Rails.root.join('tmp', 'kpi_audit_video'), ttl: 1.hour)
      @root = Pathname(root)
      @ttl = ttl
    end

    def fetch(key)
      path = @root.join("#{Digest::SHA256.hexdigest(key)}.mp4")
      FileUtils.mkdir_p(@root)
      lock_path = @root.join("#{Digest::SHA256.hexdigest(key)}.lock")
      File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |lock|
        lock.flock(File::LOCK_EX)
        return path if path.file? && path.mtime > @ttl.ago

        cleanup_expired
        yield(path)
        path
      rescue StandardError
        FileUtils.rm_f(path)
        raise
      ensure
        lock.flock(File::LOCK_UN)
      end
    end

    def cleanup_expired
      @root.glob('*.mp4').each { |path| FileUtils.rm_f(path) if path.mtime <= @ttl.ago }
    end
  end
end
