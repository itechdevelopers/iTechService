# frozen_string_literal: true

class TimeBankEventType < ApplicationRecord
  DIRECTIONS = %w[credit debit both].freeze

  has_many :time_bank_entries, foreign_key: :event_type_id, dependent: :restrict_with_error

  validates :name, presence: true
  validates :direction, presence: true, inclusion: { in: DIRECTIONS }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
  scope :for_direction, ->(dir) { where(direction: [dir, 'both']) }

  def credit?
    direction.in?(%w[credit both])
  end

  def debit?
    direction.in?(%w[debit both])
  end
end
