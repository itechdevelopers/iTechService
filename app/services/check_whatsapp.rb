require 'httparty'

class CheckWhatsapp
  include HTTParty

  base_uri ENV['GREEN_API_BASE_URL'] || 'https://api.greenapi.com'

  def self.call(number)
    return false unless configured?
    
    phone = PhoneNormalizer.normalize(number)
    return false if phone.blank?

    endpoint = "/waInstance#{instance_id}/checkWhatsapp/#{api_token}"
    headers 'Content-Type' => 'application/json'
    
    response = post(endpoint, body: { phoneNumber: phone }.to_json)
    
    response.code == 200 && response.parsed_response['existsWhatsapp'] == true
  rescue => e
    Rails.logger.error("[CheckWhatsapp] Exception: #{e.message}")
    false
  end

  private

  def self.configured?
    instance_id.present? && api_token.present?
  end

  def self.instance_id
    ENV['GREEN_API_INSTANCE_ID']
  end

  def self.api_token
    ENV['GREEN_API_TOKEN']
  end
end