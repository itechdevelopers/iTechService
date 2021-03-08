# frozen_string_literal: true

class OrderNote < ActiveRecord::Base
  scope :oldest_first, -> { order(created_at: :asc) }

  belongs_to :order, required: true
  belongs_to :author, class_name: 'User'

  delegate :department, :department_id, to: :order
  validates_presence_of :content

  def author_color
    author&.color
  end

  def author_name
    author&.full_name
  end
end
