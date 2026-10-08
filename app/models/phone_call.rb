# frozen_string_literal: true
class PhoneCall < ApplicationRecord
  DIRECTIONS = %w[incoming outgoing internal].freeze
  STATUSES = %w[answered missed busy failed].freeze
  belongs_to :caller_user, class_name: 'User', optional: true
  belongs_to :answered_user, class_name: 'User', optional: true
  validates :call_unique_id, :started_at, :caller_number, presence: true
  validates :call_unique_id, uniqueness: true, format: { with: /\A\d{10}\.\d+\z/ }
  validates :direction, inclusion: { in: DIRECTIONS }
  validates :status, inclusion: { in: STATUSES }
  validates :duration, :billsec, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :recording_path, format: { with: %r{\A/[A-Za-z0-9_./-]+\.wav\z} }, allow_nil: true
  validate :recording_in_monitor_directory
  scope :newest, -> { order(started_at: :desc, id: :desc) }

  def transcription
    CallTranscription.find_by(call_unique_id: call_unique_id)
  end

  private
  def recording_in_monitor_directory
    return if recording_path.blank?
    root = ENV.fetch('TELEPHONY_RECORDING_ROOT', '/var/spool/asterisk/monitor')
    errors.add(:recording_path, :invalid) unless File.expand_path(recording_path).start_with?(root.chomp('/') + '/') && !recording_path.split('/').include?('..')
  end
end
