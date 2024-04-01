# frozen_string_literal: true

class Message < ApplicationRecord
  scope :newest, -> { order('messages.created_at desc') }
  scope :today, -> { where('created_at > ?', Time.current.beginning_of_day) }

  belongs_to :department
  belongs_to :user
  belongs_to :recipient, polymorphic: true, optional: true
  has_many :notifications, as: :referenceable, dependent: :destroy

  validates :content, presence: true
  validates :content, length: { maximum: 255 }

  before_validation do |message|
    message.user_id = User.current.id
  end
end
