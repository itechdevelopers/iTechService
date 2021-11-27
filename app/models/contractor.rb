# frozen_string_literal: true

class Contractor < ApplicationRecord
  has_many :purchases, inverse_of: :contractor
  # attr_accessible :name
end
