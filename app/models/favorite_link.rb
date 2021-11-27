class FavoriteLink < ApplicationRecord
  belongs_to :owner, class_name: 'User'
  validates :url, presence: true
end
