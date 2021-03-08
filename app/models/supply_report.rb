# frozen_string_literal: true

class SupplyReport < ActiveRecord::Base
  scope :in_department, ->(department) { where department_id: department }
  scope :date_desc, -> { order('date desc') }

  belongs_to :department
  has_many :supplies, dependent: :destroy
  accepts_nested_attributes_for :supplies, allow_destroy: true
  # attr_accessible :date, :supplies_attributes, :department_id
  validates_presence_of :date
  validates_associated :supplies

  delegate :name, to: :department, prefix: true, allow_nil: true

  def total_cost
    if supplies.any?
      supplies.map(&:sum).sum
    else
      0
    end
  end
end
