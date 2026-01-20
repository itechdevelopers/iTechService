# frozen_string_literal: true

class OccupationType < ApplicationRecord
  validates :name, presence: true
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: :invalid_hex_color }, allow_blank: true

  default_scope { order(:position) }
end
