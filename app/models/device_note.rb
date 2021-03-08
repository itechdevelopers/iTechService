# frozen_string_literal: true

class DeviceNote < ActiveRecord::Base
  scope :newest_first, -> { order('device_notes.created_at desc') }
  scope :oldest_first, -> { order('device_notes.created_at asc') }

  belongs_to :service_job, required: true
  belongs_to :user, required: true

  delegate :department, :department_id, to: :service_job
  validates_presence_of :content

  before_validation do |device_note|
    device_note.user_id = User.current&.id
  end

  def user_name
    user&.full_name
  end
end
