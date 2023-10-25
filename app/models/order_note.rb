# frozen_string_literal: true

class OrderNote < ApplicationRecord
  scope :oldest_first, -> { order(created_at: :asc) }
  scope :newest_first, -> { order(created_at: :desc) }

  belongs_to :order
  belongs_to :author, class_name: 'User', optional: true

  delegate :department, :department_id, to: :order
  validates_presence_of :content

  def self.newest
    newest_first.first
  end

  def author_color
    author&.color
  end

  def author_name
    author&.full_name
  end
end
