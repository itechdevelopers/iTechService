# frozen_string_literal: true

class Price < ApplicationRecord
  belongs_to :department, optional: true

  mount_uploader :file, PriceUploader
  after_initialize do
    self.department_id ||= Department.current.id
  end

  def file_name
    file&.file&.original_filename
  end
end
