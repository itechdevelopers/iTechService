class Price < ActiveRecord::Base
  mount_uploader :file, PriceUploader

  belongs_to :department

  attr_accessible :file, :remove_file, :remote_file_url, :department_id

  after_initialize do
    department_id ||= Department.current.id
  end

  def file_name
    file.try(:file).try(:original_filename)
  end

end
