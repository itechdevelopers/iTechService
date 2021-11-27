class OptionType < ApplicationRecord
  # default_scope { ordered }
  scope :ordered, -> { order 'option_types.position asc' }
  has_many :option_values, inverse_of: :option_type
  accepts_nested_attributes_for :option_values, allow_destroy: true, reject_if: proc { |a| a[:name].blank? }
  validates :name, presence: true, uniqueness: true
  validates :code, uniqueness: {allow_blank: true}
  acts_as_list
end
