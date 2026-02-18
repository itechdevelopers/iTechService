# frozen_string_literal: true

class CleanAudioCacheJob < ApplicationJob
  queue_as :default

  CACHE_DIR = 'tmp/audio_cache'
  MAX_AGE = 3.days

  def perform
    dir = Rails.root.join(CACHE_DIR)
    return unless Dir.exist?(dir)

    threshold = MAX_AGE.ago
    removed = 0

    Dir.glob(dir.join('*')).each do |file|
      next unless File.file?(file)
      next unless File.mtime(file) < threshold

      File.delete(file)
      removed += 1
    end

    Rails.logger.info "[CleanAudioCache] Removed #{removed} cached files older than #{MAX_AGE.inspect}"
  end
end
