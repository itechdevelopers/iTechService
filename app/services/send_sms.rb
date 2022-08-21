require 'httparty'

class SendSMS
  include HTTParty

  attr_accessor :result
  attr_reader :number, :message

  base_uri Setting.sms_gateway_uri

  LINES = [1,2,3,4]

  def self.call(**args)
    new(args).call
  end

  def initialize(number:, message:)
    @number = number
    @message = message
    self.class.basic_auth username, password
    self.class.headers 'Accept' => '*/*'
  end

  def call
    LINES.each do |line|
      send_from line
      return self if success?
    end

    self
  end

  def success?
    result == :success
  end

  private

  def send_from(line)
    sms_key = generate_sms_key

    body = {
      line: line,
      smskey: sms_key,
      action: 'SMS',
      telnum: number,
      smscontent: message,
      send: 'Send'
    }

    response = self.class.post("/default/en_US/sms_info.html", body: body, query: {type: 'sms'})

    if response.code == 200
      @result = :success
      status = check_status(line, sms_key)
      if status == :done
        @result = :success
      else
        @result = status
      end
    else
      Rails.logger.debug("[SendSMS] line##{line}: #{response}")
      @result = response.to_s
    end
  end

  def generate_sms_key
    rand(16**8).to_s(16)
  end

  def check_status(line, sms_key)
    start_time = Time.current
    response = nil

    while true do
    #   LINES.each do |line|
        response = self.class.post('/default/en_US/send_sms_status.xml', body: {line: line},
                                   query: {u: username, p: password})
        response = response.parsed_response['send_sms_status']
        response_key = response['smskey']
        response_status = response['status']

        if response_key == sms_key
          return :done if response_status == 'DONE'
          return response['error'] unless response['error'].nil?
          return response_status if response_status != 'STARTED'
        end

        return :timeout if (Time.current - start_time) > 5.seconds
    #   end
    end

    response
  end

  def username
    ENV['GOIP_USERNAME']
  end

  def password
    ENV['GOIP_PASSWORD']
  end
end
