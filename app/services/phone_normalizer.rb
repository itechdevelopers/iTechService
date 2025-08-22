module PhoneNormalizer
  def self.normalize(number)
    return nil if number.blank?
    
    # Remove any non-digit characters
    cleaned = number.to_s.gsub(/\D/, '')
    
    # Convert Russian 8 to 7 for international format
    if cleaned.start_with?('8') && cleaned.length == 11
      cleaned = '7' + cleaned[1..]
    end
    
    # Remove leading + if present
    cleaned.gsub(/^\+/, '')
  end
end