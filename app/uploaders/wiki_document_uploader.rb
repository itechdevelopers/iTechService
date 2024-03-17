class WikiDocumentUploader < CarrierWave::Uploader::Base
  storage :fog

  def extension_allowlist
    %w(doc docx pdf xls xlsx)
  end
end