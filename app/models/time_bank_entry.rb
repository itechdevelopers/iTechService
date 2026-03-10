# frozen_string_literal: true

class TimeBankEntry < ApplicationRecord
  DIRECTIONS = %w[credit debit].freeze
  HOURS_PER_DAY = 10

  audited

  belongs_to :user
  belongs_to :schedule_group
  belongs_to :event_type, class_name: 'TimeBankEventType'
  belongs_to :created_by, class_name: 'User', optional: true

  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :minutes, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :occurred_on, presence: true
  validate :direction_matches_event_type
  validate :debit_times_consistency

  scope :credit, -> { where(direction: 'credit') }
  scope :debit, -> { where(direction: 'debit') }
  scope :for_user, ->(user) { where(user: user) }
  scope :chronological, -> { order(occurred_on: :desc, created_at: :desc) }

  def credit?
    direction == 'credit'
  end

  def debit?
    direction == 'debit'
  end

  def signed_minutes
    credit? ? minutes : -minutes
  end

  def hours
    (minutes / 60.0).round(1)
  end

  # Class method: compute balance in minutes for a user (global, across all groups)
  def self.balance_minutes_for(user)
    for_user(user)
      .sum("CASE WHEN direction = 'credit' THEN minutes ELSE -minutes END")
  end

  # Format minutes as human-readable string: "1 дн. 5 ч." or "2 ч. 30 мин."
  def self.format_balance(total_minutes)
    return '0 мин.' if total_minutes == 0

    negative = total_minutes < 0
    abs_minutes = total_minutes.abs

    days = abs_minutes / (HOURS_PER_DAY * 60)
    remaining = abs_minutes % (HOURS_PER_DAY * 60)
    hours = remaining / 60
    mins = remaining % 60

    parts = []
    parts << "#{days} дн." if days > 0
    parts << "#{hours} ч." if hours > 0
    parts << "#{mins} мин." if mins > 0
    parts = ['0 мин.'] if parts.empty?

    result = parts.join(' ')
    negative ? "-#{result}" : result
  end

  private

  def direction_matches_event_type
    return unless event_type && direction.present?

    unless event_type.direction == 'both' || event_type.direction == direction
      errors.add(:direction, "не соответствует типу мероприятия (#{event_type.direction})")
    end
  end

  def debit_times_consistency
    if debit_start_time.present? != debit_end_time.present?
      errors.add(:base, 'Укажите оба времени использования или ни одного')
    end
    if debit_start_time.present? && debit_end_time.present? && debit_end_time <= debit_start_time
      errors.add(:debit_end_time, 'должно быть позже начала')
    end
  end
end
