class Achievement < ApplicationRecord
  has_many :user_achievements
  has_many :users, through: :user_achievements

  mount_uploader :icon, IconUploader
  mount_uploader :icon_mini, IconUploader
end
