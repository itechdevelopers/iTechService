class CallTranscription < ApplicationRecord
  belongs_to :client, optional: true

  validates :call_unique_id, presence: true, uniqueness: true
  validates :transcript_text, presence: true
  validates :caller_number, presence: true
  validates :call_date, presence: true

  VALID_SENTIMENTS = %w[positive negative neutral].freeze

  before_validation :normalize_caller_number
  before_validation :find_and_link_client, on: :create
  before_validation :extract_sentiment, on: :create
  after_create_commit :check_marker_words

  # TODO: Replace with Full-Text Search when needed
  scope :search, ->(query, whole_word: false) {
    phone_query = query.gsub(/\D/, '')

    if whole_word
      escaped = query.gsub(/([.\\+*?\[\](){}|^$])/, '\\\\\1')
      text_condition = ['transcript_text ~* ?', "(^|\\s|[[:punct:]])#{escaped}($|\\s|[[:punct:]])"]
    else
      sanitized = sanitize_sql_like(query)
      text_condition = ['transcript_text ILIKE ?', "%#{sanitized}%"]
    end

    if phone_query.present?
      where("#{text_condition[0]} OR caller_number LIKE :phone",
            text_condition[1], phone: "%#{phone_query}%")
    else
      where(*text_condition)
    end
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

  def extract_sentiment
    return if transcript_text.blank? || sentiment.present?
    self.sentiment = transcript_text.scan(/\[.*?\s(positive|negative|neutral)\]/).flatten.uniq
  end

  def check_marker_words
    MarkerWordNotificationJob.perform_later(id)
  end
end
