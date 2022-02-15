# frozen_string_literal: true

class Comment < ApplicationRecord
  scope :newest, -> { order('comments.created_at desc') }
  scope :oldest, -> { order('comments.created_at asc') }

  belongs_to :user, optional: true
  belongs_to :commentable, polymorphic: true, optional: true

  delegate :department, :department_id, to: :commentable

  # attr_accessible :content, :commentable_id, :commentable_type

  validates :content, :user_id, :commentable_id, :commentable_type, presence: true

  def user_name
    user&.full_name
  end

  def user_color
    user&.color
  end
end
