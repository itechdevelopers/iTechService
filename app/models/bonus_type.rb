# frozen_string_literal: true

class BonusType < ApplicationRecord
  has_many :bonuses, dependent: :destroy, inverse_of: :bonus_type
  validates_presence_of :name
end
