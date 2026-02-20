# frozen_string_literal: true

class PhoneLabel < ApplicationRecord
  validates :phone_number, presence: true, uniqueness: true
  validates :label, presence: true

  before_validation :normalize_phone_number

  private

  def normalize_phone_number
    self.phone_number = phone_number.gsub(/\D/, '') if phone_number.present?
  end
end
