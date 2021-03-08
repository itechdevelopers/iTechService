# frozen_string_literal: true

class Brand < ApplicationRecord
  mount_uploader :logo, LogoUploader
  validates_presence_of :name
end
