class KanbanBackgroundUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :fog

  # Cap the stored image so a huge upload doesn't bloat storage or slow the
  # board page — the background is displayed with `background-size: cover`,
  # so anything beyond full-HD adds weight without visible gain.
  process resize_to_limit: [1920, 1920]

  def extension_allowlist
    %w(jpg jpeg gif png webp)
  end
end
