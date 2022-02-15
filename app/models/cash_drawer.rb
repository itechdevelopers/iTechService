# frozen_string_literal: true

class CashDrawer < ApplicationRecord
  scope :in_department, ->(department) { where(department_id: department) }

  belongs_to :department, optional: true
  has_many :cash_shifts, inverse_of: :cash_drawer

  delegate :name, to: :department, prefix: true, allow_nil: true

  # attr_accessible :name, :department_id

  validates_presence_of :name, :department

  def current_shift
    cash_shifts.opened.first_or_create(is_closed: false)
  end
end
