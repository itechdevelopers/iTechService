class Bonus < ApplicationRecord
  belongs_to :bonus_type, inverse_of: :bonuses
  has_one :karma_group, dependent: :nullify, inverse_of: :bonus
  has_many :karmas, through: :karma_group
  validates_presence_of :bonus_type
  delegate :user, to: :karma_group
  delegate :name, to: :bonus_type
end
