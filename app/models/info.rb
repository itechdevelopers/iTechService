# frozen_string_literal: true

class Info < ActiveRecord::Base
  scope :newest, -> { order('created_at desc') }
  scope :oldest, -> { order('created_at asc') }
  # scope :grouped_by_date, -> { select("date(created_at) as info_date, count(title) as total_infos").group("infos.created_at::date)") }
  scope :important, -> { where(important: true) }
  scope :available_for, ->(user) { where(recipient_id: [user.id, nil]) }
  scope :addressed_to, ->(user) { where(recipient_id: user.id) }
  scope :archived, -> { where(is_archived: true) }
  scope :actual, -> { where(is_archived: false) }

  belongs_to :department, required: true
  belongs_to :recipient, class_name: 'User', foreign_key: 'recipient_id'
  has_many :comments, as: :commentable, dependent: :destroy

  # TODO check
  accepts_nested_attributes_for :comments, allow_destroy: true, reject_if: proc { |attr| attr['content'].blank? }

  attr_accessor :comment

  # attr_accessible :content, :title, :important, :is_archived, :comment, :comments_attributes, :recipient_id, :department_id

  validates :title, :content, presence: true
  validates_associated :comments

  after_initialize do
    self.department_id ||= Department.current.id
  end

  def self.grouped_by_date
    select('date(created_at) as info_date, count(id) as total_infos').group('infos.created_at::date')
  end

  def comment=(content)
    comments.build content: content unless content.blank?
  end

  def recipient_presentation
    recipient.present? ? recipient.short_name : ''
  end

  def type_s
    recipient_id.present? ? 'personal' : 'public'
  end

  def private?
    recipient_id.present? and recipient_id == User.current.try(:id)
  end
end
