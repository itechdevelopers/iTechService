class CallTranscription < ApplicationRecord
  belongs_to :client, optional: true

  validates :call_unique_id, presence: true, uniqueness: true
  validates :transcript_text, presence: true
  validates :caller_number, presence: true
  validates :call_date, presence: true

  before_validation :normalize_caller_number
  before_validation :find_and_link_client, on: :create

  # TODO: Replace with Full-Text Search when needed:
  # scope :search_text, ->(query) { where("searchable @@ plainto_tsquery('russian', ?)", query) }
  scope :search_text, ->(query) {
    where('transcript_text ILIKE ?', "%#{sanitize_sql_like(query)}%")
  }

  private

  def normalize_caller_number
    return if caller_number.blank?
    self.caller_number = caller_number.gsub(/\D/, '')
  end

  def find_and_link_client
    return if caller_number.blank? || client.present?
    self.client = Client.where(
      'full_phone_number = :phone OR phone_number = :phone OR contact_phone = :phone',
      phone: caller_number
    ).first
  end
end
