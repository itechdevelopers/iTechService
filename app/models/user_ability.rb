class UserAbility < ApplicationRecord
  belongs_to :user
  belongs_to :ability
end