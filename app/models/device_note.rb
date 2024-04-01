# frozen_string_literal: true

class DeviceNote < ApplicationRecord
  scope :newest_first, -> { order('device_notes.created_at desc') }
  scope :oldest_first, -> { order('device_notes.created_at asc') }

  belongs_to :service_job
  belongs_to :user

  has_many :record_edits, dependent: :destroy, as: :editable
  has_many :notifications, as: :referenceable, dependent: :destroy

  delegate :department, :department_id, to: :service_job
  validates_presence_of :content

  before_validation do |device_note|
    device_note.user_id = User.current&.id
  end

  def user_name
    user&.full_name
  end
end
