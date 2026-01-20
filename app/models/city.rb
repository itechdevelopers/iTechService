class City < ApplicationRecord
  default_scope { order :name }
  scope :main, -> { joins(:departments).where(departments: {id: Department.main_branches}).distinct }

  has_many :departments, inverse_of: :city
  has_many :selectable_departments, -> { Department.selectable }, class_name: 'Department'
  has_many :shifts, dependent: :destroy
  has_many :occupation_types, dependent: :destroy

  # attr_accessible :name, :color, :time_zone
  validates_presence_of :name
end
