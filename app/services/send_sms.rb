require 'httparty'

class SendSMS
  include HTTParty

  attr_accessor :result
  attr_reader :line, :sms_key, :number, :message

  base_uri Setting.sms_gateway_uri

  def self.call(**args)
    res = nil
    1.upto(max_line).each do |line|
      args[:line] = line
      res = new(args).call
      return res if res.success?
    end
    res
  end

  def initialize(line: 1, number:, message:)
    @line = line
    @sms_key = generate_sms_key
    @number = number
    @message = message
    self.class.basic_auth username, password
    self.class.headers 'Accept' => '*/*'
  end

  def call
    response = self.class.post("/default/en_US/sms_info.html", body: post_params, query: {type: 'sms'})

    if response.code == 200
      self.result = :success
      status = check_status
      if status == :done
        self.result = :success
      else
        self.result = status
      end
    end

    self
  end

  def success?
    result == :success
  end

  def self.max_line
    Setting.sms_gateway_lines_qty
  end

  private

  def generate_sms_key
    rand(16**8).to_s(16)
  end

  def post_params
    {
      line: '1',
      smskey: sms_key,
      action: 'SMS',
      telnum: number,
      smscontent: message,
      send: 'Send'
    }
  end

  def check_status
    start_time = Time.current
    response = nil

    while true do
      1.upto(SendSMS.max_line).each do |line|
        response = self.class.post('/default/en_US/send_sms_status.xml', body: {line: line}, query: {u: username, p: password})
        response = response.parsed_response['send_sms_status']
        response_key = response['smskey']
        response_status = response['status']

        if response_key == sms_key
          return :done if response_status == 'DONE'
          return response['error'] unless response['error'].nil?
          return response_status if response_status != 'STARTED'
        end

        return :timeout if (Time.current - start_time) > 10.seconds
      end
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
