# frozen_string_literal: true

# Short clips employees send to the bot. Deliberately without MiniMagick: the
# file is already MP4/H.264 by the time it reaches us (the Telegram client
# re-encodes on send), so there is nothing to process server-side.
class ServiceJobVideoUploader < CarrierWave::Uploader::Base
  storage :fog

  # Own prefix in the bucket, unlike photos which land in the default flat
  # "uploads" — it makes the videos countable and removable as one group.
  # The record id keeps two clips with the same Telegram basename apart.
  def store_dir
    "uploads/service_job_video/#{model.id}"
  end

  def extension_allowlist
    %w[mp4 mov m4v]
  end

  # Detected by marcel from the file's magic bytes, not from its name.
  def content_type_allowlist
    [%r{\Avideo/}]
  end
end
