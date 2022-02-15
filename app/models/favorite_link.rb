class FavoriteLink < ApplicationRecord
  belongs_to :owner, class_name: 'User', optional: true
  validates :url, presence: true
end
