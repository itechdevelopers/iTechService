class UserAchievement < ApplicationRecord
  belongs_to :user
  belongs_to :achievement

  validates :user_id, presence: true
  validates :achievement_id, presence: true
end
