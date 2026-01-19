# frozen_string_literal: true

class DepartmentScheduleConfig < ApplicationRecord
  belongs_to :department

  validates :department_id, uniqueness: true
  validates :short_name, length: { maximum: 10 }, allow_blank: true
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: :invalid_hex_color }, allow_blank: true
end
