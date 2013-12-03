class Karma < ActiveRecord::Base

  belongs_to :user
  attr_accessible :comment, :good, :user_id
  validates_presence_of :user, :comment, :good
  scope :good, where(good: true)
  scope :bad, where(good: false)

  def kind
    good ? 'good' : 'bad'
  end

  def user_presentation
    user.present? ? user.presentation : ''
  end

end
