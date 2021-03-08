class City < ApplicationRecord
  default_scope { order :name }

  has_many :departments, inverse_of: :city
  has_many :selectable_departments, -> { Department.selectable }, class_name: 'Department'

  # attr_accessible :name, :color, :time_zone
  validates_presence_of :name
end
