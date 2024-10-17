# frozen_string_literal: true

class OrderNote < ApplicationRecord
  include Auditable

  scope :oldest_first, -> { order(created_at: :asc) }
  scope :newest_first, -> { order(created_at: :desc) }

  belongs_to :order
  belongs_to :author, class_name: 'User', optional: true

  has_many :record_edits, dependent: :destroy, as: :editable
  has_many :notifications, as: :referenceable, dependent: :destroy

  delegate :department, :department_id, to: :order
  validates_presence_of :content

  audited associated_with: :order

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
