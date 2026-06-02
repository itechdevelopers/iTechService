# frozen_string_literal: true

class TestingSession < ApplicationRecord
  belongs_to :service_job
  belongs_to :sender,          class_name: 'User',     optional: true
  belongs_to :target_location, class_name: 'Location', optional: true
  belongs_to :tester,          class_name: 'User',     optional: true

  enum status: {
    not_started: 'not_started',
    in_progress: 'in_progress',
    passed:      'passed',
    failed:      'failed'
  }

  FAILURE_ACTIONS = {
    return_to_tech: 'return_to_tech',
    retry:          'retry'
  }.freeze

  validates :status, presence: true
  validates :failure_action, inclusion: { in: FAILURE_ACTIONS.values }, allow_nil: true

  scope :chronological, -> { order(:created_at) }
  scope :finished,      -> { where(status: %w[passed failed]) }

  # Длительность теста в секундах (nil, пока тест не завершён).
  def duration
    return nil unless started_at && ended_at
    ended_at - started_at
  end
end
