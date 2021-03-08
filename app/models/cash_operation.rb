# frozen_string_literal: true

class CashOperation < ActiveRecord::Base
  scope :in_department, ->(department) { where(cash_shift_id: CashShift.in_department(department)) }
  scope :created_desc, -> { order('created_at desc') }

  belongs_to :cash_shift, inverse_of: :cash_operations
  belongs_to :user
  delegate :short_name, to: :user, prefix: true, allow_nil: true
  delegate :department, :department_id, to: :cash_shift

  # attr_accessible :is_out, :value, :comment
  validates_presence_of :value, :user, :cash_shift
  validates_presence_of :comment, if: :is_out
  validates_numericality_of :value, greater_than: 0
  before_validation :set_user_and_cash_shift
  after_initialize :set_user_and_cash_shift

  def kind
    is_out ? 'cash_out' : 'cash_in'
  end

  private

  def set_user_and_cash_shift
    self.user_id ||= User.current.try(:id)
    self.cash_shift_id ||= User.current.try(:current_cash_shift).try(:id)
  end
end
