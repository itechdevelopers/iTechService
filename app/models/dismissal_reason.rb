class DismissalReason < ApplicationRecord
  default_scope { order(id: :asc) }
  has_many :users
  validates_presence_of :name
end