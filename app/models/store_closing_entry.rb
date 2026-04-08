# frozen_string_literal: true

class StoreClosingEntry < ApplicationRecord
  belongs_to :department
  belongs_to :user
  belongs_to :assigned_by, class_name: 'User', optional: true

  validates :date, presence: true
  validates :user_id, uniqueness: { scope: %i[department_id date] }

  scope :for_department, ->(department) { where(department_id: department) }
  scope :for_date_range, ->(from, to) { where(date: from..to) }
  scope :for_month, ->(date) { where(date: date.beginning_of_month..date.end_of_month) }
  scope :today, -> { where(date: Date.current) }
end
