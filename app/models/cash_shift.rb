# frozen_string_literal: true

class CashShift < ApplicationRecord
  scope :in_department, ->(department) { where(cash_drawer_id: CashDrawer.in_department(department)) }

  scope :closed, -> { where(is_closed: true) }
  scope :opened, -> { where(is_closed: false) }

  belongs_to :cash_drawer, inverse_of: :cash_shifts
  belongs_to :user
  has_many :sales, inverse_of: :cash_shift
  has_many :cash_operations, inverse_of: :cash_shift
  delegate :short_name, to: :user, prefix: true, allow_nil: true
  delegate :department, :department_id, to: :cash_drawer
  validates_presence_of :cash_drawer

  def close
    if is_closed
      errors[:base] << t('cash_shifts.errors.already_closed')
    else
      sales.unposted.destroy_all
      update_attribute :is_closed, true
      update_attribute :closed_at, DateTime.current
      update_attribute :user_id, User.current
    end
  end

  def sales_total(is_return = false)
    sales.posted.where(is_return: is_return).to_a.sum(&:payments_sum)
  end

  def sales_total_by_kind(is_return = false)
    res = []
    sale_ids = sales.posted.where(is_return: is_return).map(&:id)
    Payment::KINDS.each do |kind|
      value = Payment.where(kind: kind, sale_id: sale_ids).sum(:value)
      res << [kind, value]
    end
    res
  end

  def sales_count(is_return = false)
    sales.posted.where(is_return: is_return).count
  end

  def cash_operations_total(is_out = false)
    cash_operations.where(is_out: is_out).sum(:value)
  end

  def cash_operations_balance
    cash_operations_total - cash_operations_total(true)
  end

  def encashments_by_kind
    res = []
    sale_ids = sales.posted.selling.map(&:id)
    return_ids = sales.posted.returning.map(&:id)
    Payment::KINDS.each do |kind|
      value = Payment.where(kind: kind,
                            sale_id: sale_ids).sum(:value) - Payment.where(kind: kind, sale_id: return_ids).sum(:value)
      value += cash_operations_balance if kind == 'cash'
      res << [kind, value]
    end
    res
  end

  def encashment_total
    sales_total - sales_total(true) + cash_operations_balance
  end
end
