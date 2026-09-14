class City < ApplicationRecord
  default_scope { order :name }
  # Города, где есть действующие подразделения. Подзапросом, а не joins:
  # у Department свой default_scope с сортировкой, и merge затащил бы
  # ORDER BY departments.id в выборку с DISTINCT, чего Postgres не допускает.
  scope :with_real_departments, -> { where(id: Department.real.reorder(nil).select(:city_id)) }
  scope :main, -> { joins(:departments).where(departments: {id: Department.main_branches}).distinct }

  has_many :departments, inverse_of: :city
  has_many :selectable_departments, -> { Department.selectable }, class_name: 'Department'
  has_many :schedule_groups, dependent: :destroy
  has_many :plans, dependent: :destroy

  # attr_accessible :name, :color, :time_zone
  validates_presence_of :name
end
