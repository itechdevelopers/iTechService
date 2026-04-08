# frozen_string_literal: true

class StoreClosingGroup < ApplicationRecord
  belongs_to :department
  belongs_to :created_by, class_name: 'User', optional: true

  has_many :store_closing_memberships, dependent: :destroy
  has_many :members, through: :store_closing_memberships, source: :user

  validates :department_id, uniqueness: true
end
