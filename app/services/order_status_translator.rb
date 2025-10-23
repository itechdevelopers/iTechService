# frozen_string_literal: true

# Service for bidirectional translation between English and Cyrillic status values
# Used for 1C API integration where statuses are sent/received in CamelCase Cyrillic format
class OrderStatusTranslator
  # Status translations: English (database format) ↔ Cyrillic (1C format)
  STATUS_TRANSLATIONS = {
    'current' => 'ВРаботе',
    'on_the_way' => 'ВПутиНаФилиал',
    'done' => 'Дозваниваемся',
    'notified' => 'Уведомлен',
    'archive' => 'Архив'
  }.freeze

  # Archive reason translations: English (database format) ↔ Cyrillic (1C format)
  ARCHIVE_REASON_TRANSLATIONS = {
    'order_picked_up' => 'ЗаказЗабрали',
    'order_cancelled_by_customer' => 'ЗаказОтменилКлиент',
    'order_cancelled_by_company' => 'ЗаказОтменилаКомпания',
    'order_created_by_mistake' => 'ЗаказСозданПоОшибке'
  }.freeze

  # Reverse mappings for fast lookup
  CYRILLIC_TO_STATUS = STATUS_TRANSLATIONS.invert.freeze
  CYRILLIC_TO_ARCHIVE_REASON = ARCHIVE_REASON_TRANSLATIONS.invert.freeze

  class << self
    # Translate English value to Cyrillic
    # @param value [String] English value (e.g., 'current', 'order_picked_up')
    # @param type [Symbol] :status or :archive_reason
    # @return [String, nil] Cyrillic value or nil if not found
    def to_cyrillic(value, type: :status)
      return nil if value.blank?

      dictionary = type == :status ? STATUS_TRANSLATIONS : ARCHIVE_REASON_TRANSLATIONS
      dictionary[value.to_s.downcase]
    end

    # Translate Cyrillic value to English
    # @param value [String] Cyrillic value (e.g., 'ВРаботе', 'ЗаказЗабрали')
    # @param type [Symbol] :status or :archive_reason
    # @return [String, nil] English value or nil if not found
    def to_english(value, type: :status)
      return nil if value.blank?

      # Try exact match first
      dictionary = type == :status ? CYRILLIC_TO_STATUS : CYRILLIC_TO_ARCHIVE_REASON
      result = dictionary[value.to_s]

      # If not found, try case-insensitive match
      unless result
        downcased_value = value.to_s.downcase
        result = dictionary.find { |k, _v| k.downcase == downcased_value }&.last
      end

      result
    end

    # Get all valid Cyrillic status values
    # @return [Array<String>] Array of Cyrillic statuses
    def valid_cyrillic_statuses
      STATUS_TRANSLATIONS.values
    end

    # Get all valid English status values
    # @return [Array<String>] Array of English statuses
    def valid_english_statuses
      STATUS_TRANSLATIONS.keys
    end

    # Get all valid Cyrillic archive reasons
    # @return [Array<String>] Array of Cyrillic archive reasons
    def valid_cyrillic_archive_reasons
      ARCHIVE_REASON_TRANSLATIONS.values
    end

    # Get all valid English archive reasons
    # @return [Array<String>] Array of English archive reasons
    def valid_english_archive_reasons
      ARCHIVE_REASON_TRANSLATIONS.keys
    end

    # Check if a value is a valid status (in either language)
    # @param value [String] Status value to check
    # @return [Boolean] true if valid
    def valid_status?(value)
      return false if value.blank?

      STATUS_TRANSLATIONS.key?(value.to_s.downcase) ||
        CYRILLIC_TO_STATUS.key?(value.to_s)
    end

    # Check if a value is a valid archive reason (in either language)
    # @param value [String] Archive reason value to check
    # @return [Boolean] true if valid
    def valid_archive_reason?(value)
      return false if value.blank?

      ARCHIVE_REASON_TRANSLATIONS.key?(value.to_s.downcase) ||
        CYRILLIC_TO_ARCHIVE_REASON.key?(value.to_s)
    end
  end
end