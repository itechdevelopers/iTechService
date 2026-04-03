# frozen_string_literal: true

class CashierNotificationPhrase < ApplicationRecord
  validates :text, presence: true

  scope :active, -> { where(active: true) }

  def self.random_active
    active.order('RANDOM()').first
  end
end
