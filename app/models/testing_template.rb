# frozen_string_literal: true

class TestingTemplate < ApplicationRecord
  validates :content, presence: true

  scope :ordered, -> { order(:position) }
end
