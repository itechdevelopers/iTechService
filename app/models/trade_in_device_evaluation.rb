class TradeInDeviceEvaluation < ApplicationRecord
  scope :ordered, -> { joins(:product_group).order('product_groups.position ASC').order('name ASC') }

  belongs_to :product_group
  delegate :available_trade_in_options, to: :product_group, allow_nil: true

  validates :name, uniqueness: true
  validates :min_value, :max_value, numericality: { greater_than_or_equal_to: 0 }
  
  def self.construct_name(product_group_id, option_ids)
    res = ProductGroup.find(product_group_id).name
    res << " (#{OptionValue.find(option_ids).map(&:name).join(' ')})" if option_ids.present?
    res
  end

  def generic_group
    if product_group.name == "Apple Watch"
      return "Watch"
    else
      return product_group.parent.name
    end
  end
end
