class OrderExternalSync < ApplicationRecord
  # Constants following existing codebase patterns
  EXTERNAL_SYSTEMS = %w[one_c].freeze
  SYNC_STATUSES = %w[pending syncing synced failed permanently_failed].freeze
  
  # Maximum retry attempts before marking as permanently failed
  MAX_RETRY_ATTEMPTS = 5
  
  # Associations
  belongs_to :order
  
  # Enums following existing integer enum pattern
  enum external_system: { one_c: 0 }
  enum sync_status: { 
    pending: 0, 
    syncing: 1, 
    synced: 2, 
    failed: 3, 
    permanently_failed: 4 
  }
  
  # Validations
  validates :order_id, :external_system, :sync_status, presence: true
  validates :sync_attempts, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: MAX_RETRY_ATTEMPTS }
  validates :order_id, uniqueness: { scope: :external_system }
  
  # Custom validations based on status
  validates :external_id, presence: true, if: :synced?
  
  # Scopes for common queries
  scope :requires_attention, -> { where(attention_required: true) }
  scope :recently_failed, -> { failed.where('last_attempt_at > ?', 1.hour.ago) }
  
  # Note: retry-related scopes removed as ActiveJob handles retry scheduling
  
  # Instance methods
  # Note: Retry logic is now handled by ActiveJob in OneCOrderSyncJob
  # sync_attempts field is kept for monitoring and reporting purposes
  
  def mark_sync_success!(external_id = nil)
    # Only clear attention if article doesn't require attention anymore
    clear_attention = !requires_article_attention?
    
    # Use external_number from 1C
    sync_external_id = external_id
    
    update!(
      sync_status: :synced,
      external_id: sync_external_id,
      last_error: nil,
      attention_required: clear_attention ? false : attention_required
    )
  end
  
  def mark_sync_failure!(error_message)
    new_status = sync_attempts >= MAX_RETRY_ATTEMPTS ? :permanently_failed : :failed
    update!(
      sync_status: new_status,
      last_error: error_message,
      attention_required: true  # Sync failures always require attention
    )
  end
  
  def requires_article_attention?
    attention_required? && order.device_order? && (order.article.blank? || order.article.strip.blank?)
  end

  def clear_attention_required!
    update!(attention_required: false)
  end

  def mark_attention_resolved!
    update!(attention_required: false)
  end
  
  private
end