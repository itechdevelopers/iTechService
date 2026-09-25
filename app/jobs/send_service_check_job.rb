# frozen_string_literal: true

# Отправка отложенного чека в 1С. Ретраи повторяют тот же uid, поэтому
# повторная отправка обязана попасть в тот же чек 1С, а не создать второй.
class SendServiceCheckJob < ApplicationJob
  queue_as :default

  class TransientError < StandardError; end

  retry_on TransientError, wait: :exponentially_longer, attempts: 5

  def perform(checkout_id)
    checkout = ServiceJobCheckout.find(checkout_id)
    # Оплаченный или отозванный расчёт догонять нечем: чек уже живёт своей
    # жизнью в 1С.
    return unless checkout.draft? || checkout.send_failed?

    builder = ServiceJobs::CheckoutPayloadBuilder.new(checkout)
    checkout.update!(attempts: checkout.attempts + 1,
                     items_snapshot: builder.items,
                     expected_total: builder.total)

    result = ServiceCheckClient.new.create_check(builder.call)
    data = parsed_data(result[:data])

    if result[:success] && data['Executed']
      mark_sent(checkout, data)
    else
      handle_failure(checkout, error_message(result, data))
    end
  end

  private

  def mark_sent(checkout, data)
    checkout.update!(state: :sent,
                     sent_at: Time.current,
                     check_guid: data['check_guid'].presence || checkout.check_guid,
                     check_number: data['check_number'].presence || checkout.check_number,
                     last_error: nil)
    Rails.logger.info "[ServiceCheck] Checkout #{checkout.id} sent to 1C, uid=#{checkout.uid}"
  end

  def handle_failure(checkout, message)
    checkout.update!(state: :send_failed, last_error: message)
    Rails.logger.warn "[ServiceCheck] Checkout #{checkout.id} failed: #{message}"

    # 4xx — это наша ошибка в запросе, повтор ничего не изменит. Всё остальное
    # (сеть, таймаут, упавшая публикация 1С) лечится ретраем.
    raise TransientError, message unless client_error?(message)
  end

  def client_error?(message)
    message.to_s.match?(/Код ответа: 4\d{2}/)
  end

  def error_message(result, data)
    data['Error'].presence || result[:error].presence || 'Неизвестная ошибка 1С'
  end

  def parsed_data(data)
    return data if data.is_a?(Hash)

    JSON.parse(data.to_s.strip)
  rescue JSON::ParserError
    {}
  end
end
