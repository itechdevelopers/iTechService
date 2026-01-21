# frozen_string_literal: true

class ScheduleGroup < ApplicationRecord
  belongs_to :city
  belongs_to :owner, class_name: 'User', foreign_key: 'user_id'

  has_many :memberships, class_name: 'ScheduleGroupMembership', dependent: :destroy
  has_many :members, through: :memberships, source: :user

  validates :name, presence: true

  def owned_by?(user)
    user_id == user.id
  end
end
