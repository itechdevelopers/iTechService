# frozen_string_literal: true

class PhoneLabel < ApplicationRecord
  belongs_to :department, optional: true
  belongs_to :user, optional: true

  validates :department, presence: true, if: :department_id?
  validates :user, presence: true, if: :user_id?

  validates :group_name, length: { maximum: 100 }, allow_nil: true

  validates :phone_number, presence: true, uniqueness: true
  validates :label, presence: true

  before_validation :normalize_phone_number

  private

  def normalize_phone_number
    self.group_name = group_name.to_s.strip.presence
    self.phone_number = phone_number.gsub(/\D/, '') if phone_number.present?
  end
end
