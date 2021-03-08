# frozen_string_literal: true

class TopSalable < ActiveRecord::Base
  has_ancestry orphan_strategy: :destroy
  scope :ordered, -> { order('position asc') }
  belongs_to :product
  delegate :name, to: :product, prefix: true, allow_nil: true
  validates_numericality_of :position, only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 20
  validates_uniqueness_of :position, scope: :ancestry
  after_initialize { self.type ||= 'Group' }

  def title
    product_name || name
  end

  def type=(value)
    if value == 'Group'
      self.product_id = nil
    else
      self.name = nil
    end
  end

  def type
    product.present? ? 'Product' : 'Group'
  end
end
