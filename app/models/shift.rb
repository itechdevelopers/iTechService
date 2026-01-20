# frozen_string_literal: true

class Shift < ApplicationRecord
  validates :name, presence: true
  validates :short_name, length: { maximum: 10 }, allow_blank: true

  default_scope { order(:position) }
end
