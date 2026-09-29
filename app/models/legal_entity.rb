# frozen_string_literal: true

class LegalEntity < ApplicationRecord
  has_many :departments, dependent: :restrict_with_error

  scope :ordered, -> { order(:name) }

  validates :name, :ogrn_inn, :legal_address, presence: true
end
