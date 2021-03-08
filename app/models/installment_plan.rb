# frozen_string_literal: true

class InstallmentPlan < ActiveRecord::Base
  scope :issued_at, ->(period) { where(issued_at: period) }
  scope :closed, -> { where(is_closed: true) }
  scope :not_closed, -> { where(is_closed: [false, nil]) }

  belongs_to :user, inverse_of: :installment_plans
  has_many :installments, inverse_of: :installment_plan, dependent: :destroy

  delegate :department, :department_id, to: :user

  accepts_nested_attributes_for :installments, reject_if: lambda { |attrs|
                                                            attrs['installment_plan_id'].blank? or attrs['value'].blank? or attrs['paid_at'].blank?
                                                          }
  # attr_accessible :cost, :issued_at, :object, :user, :user_id, :installments_attributes, :is_closed

  validates_presence_of :user, :object, :cost, :issued_at

  after_initialize do |rec|
    rec.issued_at ||= Date.current
  end

  def paid_sum
    installments.sum(:value)
  end

  def presentation
    "#{object}, #{paid_sum}/#{cost}, #{issued_at.strftime('%d.%m.%y')}"
  end
end
