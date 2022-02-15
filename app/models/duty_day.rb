class DutyDay < ApplicationRecord
  KINDS = %w[kitchen salesroom]

  default_scope { order('day desc') }
  scope :in_department, ->(department) { where user_id: User.in_department(department) }
  scope :in_city, ->(city) { where user_id: User.in_city(city) }
  scope :duties_except_user, ->(user) { where.not(user_id: user) }
  scope :kitchen, -> { where(kind: 'kitchen') }
  scope :salesroom, -> { where(kind: 'salesroom') }

  belongs_to :user, optional: true

  delegate :department, :department_id, to: :user

  # attr_accessible :day, :user_id, :kind

  validates_presence_of :day, :user_id, :kind
  validates_inclusion_of :kind, in: KINDS

  def self.get_for(city, kind, day)
    in_city(city).find_by(kind: kind, day: day)
  end
end
