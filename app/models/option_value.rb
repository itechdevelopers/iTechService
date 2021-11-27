class OptionValue < ApplicationRecord
  # default_scope { ordered }
  scope :ordered, -> { includes(:option_type).order('option_types.position asc, option_values.position asc') }
  scope :defined, -> { where.not code: '?' }
  scope :undefined, -> { where code: '?' }
  belongs_to :option_type, required: true, inverse_of: :option_values

  validates :name, presence: true, uniqueness: true
  validates :code, uniqueness: {allow_blank: true}
  acts_as_list scope: :option_type

  def undefined?
    code == '?'
  end
end
