class Bonus < ApplicationRecord
  belongs_to :bonus_type, inverse_of: :bonuses, optional: true
  has_one :karma_group, dependent: :nullify, inverse_of: :bonus
  has_many :karmas, through: :karma_group
  # attr_accessible :comment, :bonus_type_id
  validates_presence_of :bonus_type
  delegate :user, to: :karma_group
  delegate :name, to: :bonus_type
end
