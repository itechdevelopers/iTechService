class EmploymentPeriod < ApplicationRecord
  belongs_to :user
  belongs_to :dismissal_reason, optional: true

  validates :started_at, presence: true
  validate :ended_at_after_started_at, if: :ended_at?

  scope :chronological, -> { order(started_at: :asc) }
  scope :current, -> { where(ended_at: nil) }

  def duration_months
    end_date = ended_at || Date.current
    ((end_date.year * 12 + end_date.month) - (started_at.year * 12 + started_at.month))
  end

  def duration_text
    total_months = duration_months
    years = total_months / 12
    months = total_months % 12

    parts = []
    if years > 0
      word = if years == 1 || (years > 20 && years % 10 == 1)
               'год'
             elsif (years < 5 || years > 20) && (years % 10).in?(2..4)
               'года'
             else
               'лет'
             end
      parts << "#{years} #{word}"
    end
    parts << "#{months} мес." if months > 0
    if parts.empty?
      end_date = ended_at || Date.current
      days = (end_date - started_at).to_i
      word = if days % 10 == 1 && days != 11
               'день'
             elsif (days % 10).in?(2..4) && !days.in?(12..14)
               'дня'
             else
               'дней'
             end
      parts << "#{days} #{word}"
    end
    parts.join(' ')
  end

  def active?
    ended_at.nil?
  end

  private

  def ended_at_after_started_at
    if ended_at < started_at
      errors.add(:ended_at, 'должна быть позже даты начала')
    end
  end
end
