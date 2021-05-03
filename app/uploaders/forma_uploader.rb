class FormaUploader < ApplicationUploader
  def store_dir
    'uploads'
  end

  def extension_white_list
    ['pdf']
  end
end
