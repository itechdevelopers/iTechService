# frozen_string_literal: true

class StoreClosingNotificationPhrase < ApplicationRecord
  validates :text, presence: true

  scope :active, -> { where(active: true) }

  def self.random_active
    active.order('RANDOM()').first
  end
end
