require 'httparty'

class SendWhatsapp
  include HTTParty

  attr_reader :result, :message_id

  base_uri ENV['GREEN_API_BASE_URL'] || 'https://api.greenapi.com'

  def self.call(number:, message:)
    new.send_message(number: number, message: message)
  end

  def initialize
    self.class.headers 'Content-Type' => 'application/json'
    @result = nil
    @message_id = nil
  end

  def send_message(number:, message:)
    phone = PhoneNormalizer.normalize(number)
    
    unless configured?
      @result = I18n.t('service.sms_notification.whatsapp_not_configured')
      return self
    end

    unless Setting.whatsapp_enabled?
      @result = I18n.t('service.sms_notification.whatsapp_not_enabled')
      return self
    end

    unless CheckWhatsapp.call(phone)
      @result = I18n.t('service.sms_notification.client_no_whatsapp')
      return self
    end

    endpoint = "/waInstance#{instance_id}/sendMessage/#{api_token}"
    body = { chatId: "#{phone}@c.us", message: message }

    response = self.class.post(endpoint, body: body.to_json)

    if response.code == 200 && response['idMessage']
      @message_id = response['idMessage']
      @result = :success
    else
      @result = I18n.t('service.sms_notification.whatsapp_send_failed', 
                       error: response['error'] || "HTTP #{response.code}")
    end

    self
  rescue => e
    Rails.logger.error("[SendWhatsapp] Exception: #{e.message}")
    @result = I18n.t('service.sms_notification.whatsapp_send_failed', error: e.message)
    self
  end

  def success?
    @result == :success
  end

  private

  def configured?
    instance_id.present? && api_token.present?
  end

  def instance_id
    ENV['GREEN_API_INSTANCE_ID']
  end

  def api_token
    ENV['GREEN_API_TOKEN']
  end
end