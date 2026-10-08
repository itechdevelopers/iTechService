# frozen_string_literal: true
# Machine-only ingestion, isolated from employee sessions and CSRF forms.
class TelephonyImportsController < ActionController::Base
  MAX_BYTES = 256 * 1024
  def create
    secret = ENV['TELEPHONY_INGEST_SECRET'].to_s
    return head(:service_unavailable) if secret.bytesize < 32
    return head(:payload_too_large) if request.content_length.to_i > MAX_BYTES
    body = request.body.read(MAX_BYTES + 1)
    return head(:payload_too_large) if body.bytesize > MAX_BYTES
    stamp = request.headers['X-AIS-Timestamp'].to_s
    return head(:unauthorized) unless stamp.match?(/\A\d{10}\z/) && (Time.now.to_i - stamp.to_i).abs <= 300
    signature = request.headers['X-AIS-Signature'].to_s
    expected = OpenSSL::HMAC.hexdigest('SHA256', secret, stamp + '.' + body)
    return head(:unauthorized) unless signature.bytesize == expected.bytesize && ActiveSupport::SecurityUtils.secure_compare(signature, expected)
    payload = JSON.parse(body)
    return head(:unprocessable_entity) unless payload.is_a?(Hash)
    calls = payload.fetch('calls')
    return head(:unprocessable_entity) unless calls.is_a?(Array) && calls.length <= 100 && calls.all? { |c| c.is_a?(Hash) }
    # Whole batch commits or none; sender can retry a failed request safely.
    PhoneCall.transaction { calls.each { |attrs| Telephony::ImportCall.call(attrs) } }
    render json: { accepted: calls.length }
  rescue JSON::ParserError, KeyError, ActiveRecord::RecordInvalid, ArgumentError
    render json: { error: 'Invalid call batch' }, status: :unprocessable_entity
  end
end
