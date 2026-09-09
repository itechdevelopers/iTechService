# frozen_string_literal: true

# Cover frame for a ServiceJobVideo. Telegram sends it alongside the video as
# a ready JPEG thumbnail, so we only store it — no frame extraction needed.
class ServiceJobVideoPosterUploader < CarrierWave::Uploader::Base
  storage :fog

  def store_dir
    "uploads/service_job_video/#{model.id}/poster"
  end

  def extension_allowlist
    %w[jpg jpeg png]
  end

  def content_type_allowlist
    [%r{\Aimage/}]
  end
end
