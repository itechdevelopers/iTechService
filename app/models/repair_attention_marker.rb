class RepairAttentionMarker < ApplicationRecord
  belongs_to :service_job
  belongs_to :user
  belongs_to :status_at_view, class_name: 'RepairStatus', optional: true
  belongs_to :processed_by, class_name: 'User', optional: true

  enum processed_action: {
    dismissed:     'dismissed',
    started:       'started',
    auto_resolved: 'auto_resolved'
  }

  validates :viewed_at, presence: true
  validates :dismiss_token, :start_token, presence: true, uniqueness: true

  before_validation :generate_tokens, on: :create

  scope :unprocessed, -> { where(processed_at: nil) }
  scope :processed,   -> { where.not(processed_at: nil) }

  def processed?
    processed_at.present?
  end

  def dismiss!
    return if processed?

    update!(processed_at: Time.zone.now, processed_action: 'dismissed')
  end

  def mark_started!(user)
    return if processed?

    update!(processed_at: Time.zone.now, processed_action: 'started', processed_by: user)
  end

  def mark_auto_resolved!
    return if processed?

    update!(processed_at: Time.zone.now, processed_action: 'auto_resolved')
  end

  private

  def generate_tokens
    self.dismiss_token ||= SecureRandom.urlsafe_base64(24)
    self.start_token   ||= SecureRandom.urlsafe_base64(24)
  end
end
