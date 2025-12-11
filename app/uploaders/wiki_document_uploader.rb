class WikiDocumentUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage :fog

  version :thumb, if: :image? do
    process resize_to_limit: [200, 200]
  end

  def extension_allowlist
    %w(doc docx pdf xls xlsx jpg jpeg gif png)
  end

  def image?(new_file = nil)
    return false unless file.present?

    %w(jpg jpeg gif png).include?(file.extension&.downcase)
  end
end