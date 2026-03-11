# frozen_string_literal: true

class TimeBankEntry < ApplicationRecord
  DIRECTIONS = %w[credit debit].freeze

  audited

  belongs_to :user
  belongs_to :schedule_group
  belongs_to :event_type, class_name: 'TimeBankEventType'
  belongs_to :created_by, class_name: 'User', optional: true

  validates :direction, presence: true, inclusion: { in: DIRECTIONS }
  validates :occurred_on, presence: true
  validates :minutes, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :days, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validate :direction_matches_event_type
  validate :debit_times_consistency
  validate :days_or_minutes_present

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

  # Class method: compute balance for a user (global, across all groups)
  # Returns { days: Integer, minutes: Integer }
  def self.balance_for(user)
    result = for_user(user).select(
      Arel.sql("COALESCE(SUM(CASE WHEN direction = 'credit' THEN days ELSE -days END), 0) AS total_days"),
      Arel.sql("COALESCE(SUM(CASE WHEN direction = 'credit' THEN minutes ELSE -minutes END), 0) AS total_minutes")
    ).take
    { days: result.total_days.to_i, minutes: result.total_minutes.to_i }
  end

  # Format a single entry's amount (always positive, for display in tables)
  def self.format_amount(days, minutes)
    parts = []
    parts << "#{days} дн." if days > 0
    hours = minutes / 60
    mins = minutes % 60
    parts << "#{hours} ч." if hours > 0
    parts << "#{mins} мин." if mins > 0
    parts.empty? ? '0 мин.' : parts.join(' ')
  end

  # Format balance (can be negative)
  def self.format_balance(days, minutes)
    # Determine overall sign: negative if both components are non-positive and at least one is negative
    if days < 0 || minutes < 0
      abs_days = days.abs
      abs_minutes = minutes.abs
      "-#{format_amount(abs_days, abs_minutes)}"
    else
      format_amount(days, minutes)
    end
  end

  private

  def days_or_minutes_present
    if (days.nil? || days == 0) && (minutes.nil? || minutes == 0)
      errors.add(:base, 'Укажите количество дней или времени')
    end
  end

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
