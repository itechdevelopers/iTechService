class Ability < ApplicationRecord
  has_many :user_abilities
  has_many :users, through: :user_abilities

  scope :admin_assignable, -> { where(admin_assignable: true) }
end
