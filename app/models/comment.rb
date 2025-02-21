# frozen_string_literal: true

class Comment < ApplicationRecord
  include Auditable

  scope :newest, -> { order('comments.created_at desc') }
  scope :oldest, -> { order('comments.created_at asc') }

  belongs_to :user, optional: true
  belongs_to :commentable, polymorphic: true, optional: true

  has_many :record_edits, dependent: :destroy, as: :editable
  has_many :notifications, as: :referenceable, dependent: :destroy

  delegate :department, :department_id, to: :commentable

  # attr_accessible :content, :commentable_id, :commentable_type

  validates :content, :user_id, :commentable_id, :commentable_type, presence: true

  audited associated_with: :commentable,
          if: :should_audit_for_commentable?

  def user_name
    user&.full_name
  end

  def user_color
    user&.color
  end

  private

  def should_audit_for_commentable?
    %w[QuickOrder Kanban::Card].include? commentable_type
  end
end
