# frozen_string_literal: true

class Message < ActiveRecord::Base
  scope :newest, -> { order('messages.created_at desc') }
  scope :today, -> { where('created_at > ?', Time.current.beginning_of_day) }

  belongs_to :department, required: true
  belongs_to :user, required: true
  belongs_to :recipient, polymorphic: true
  validates :content, presence: true
  validates :content, length: { maximum: 255 }

  before_validation do |message|
    message.user_id = User.current.id
  end
end
