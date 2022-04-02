class FormaUploader < ApplicationUploader
  def store_dir
    'uploads'
  end

  def extension_white_list
    ['pdf']
  end

  def filename
    "forma.pdf"
  end

  def full_path
    File.join(root, store_path)
  end
end
